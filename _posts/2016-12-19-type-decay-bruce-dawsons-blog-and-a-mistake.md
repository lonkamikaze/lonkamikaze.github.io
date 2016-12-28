---
title:   "Type Decay, Bruce Dawson's Blog and a Mistake"
journal: 1
tags:
- C++
---

[randomascii]: https://randomascii.wordpress.com
[strncpy]:     https://randomascii.wordpress.com/2013/04/03/stop-using-strncpy-already/
[formatting]:  {% post_url 2016-12-16-cxx-printf-style-formatting %}
{% include man.md p="sprintf" s=3 %}
{% include man.md p="snprintf" s=3 %}
This post is about why you should read [Bruce Dawson's blog][randomascii],
how an error crept into my last article and what the two have to
do with each other.

I'll start with the error.

A Dangerous Mistake
-------------------

Today I noticed a dangerous error in [my last post][formatting]:

~~~ diff
 template <typename... ArgTs>
 std::string operator ()(ArgTs const &... args) const {
 	char buf[BufSize];
-	auto size = sprintf(buf, this->fmt, args...);
+	auto size = snprintf(buf, BufSize, this->fmt, args...);
 	if (size >= BufSize) {
 		/* does not fit into buffer */
 		return {buf, BufSize - 1};
~~~
Fix a potential write beyond end of buffer bug in my
[C++ string formatting article][formatting].

So I accidentally used the unsafe [`sprintf(3)`] instead of the safer
[`snprintf(3)`], which takes the target buffer size to make sure it
does not write beyond the end of the buffer and ensures 0 termination.

This is a serious mistake. For a properly chosen `BufSize`, this kind
of bug does not get triggered for years and the faulty code might
end up relied upon in many different places where it is exploitable,
e.g. by a user supplying data that is tailored to be larger than the
buffer.

Type Decay of Arrays
--------------------

C++ inherits the unfortunate property of C arrays, that what is an
array in the current scope, turns into a pointer when passed into
a function:

~~~ c++
#include <iostream>

void test_decay(char buf[]) {
	std::cout << "test_decay: " << sizeof(buf) << '\n';
}

int main() {
	char buf[1337];
	std::cout << "main: " << sizeof(buf) << '\n';
	test_decay(buf);
	return 0;
}
~~~
Illustrate array decaying.

~~~
main: 1337
test_decay: 8
~~~
The output.

So the `main()` outputs the size of the array, while `test_decay()`
prints the size of a `char * const`.

The syntax allows providing the length of the buffer:

~~~ c++
void test_array(char buf[1337]) {
	std::cout << "test_array: " << sizeof(buf) << '\n';
}
~~~
Misleading syntax.

~~~
test_array: 8
~~~
The output.

So even supplying an array size does not prevent decay, even worse
compilers do not enforce interface compliance, handing in a buffer
of the wrong size is silently accepted.

Bruce Dawson to the Rescue
--------------------------

I became aware of a solution to this when reading Bruce Dawson's article
[Stop using strncpy already!][strncpy].

This issue can be circumvented by using C++ array references:

~~~ c++
void test_array_ref(char (& buf)[1337]) {
	std::cout << "test_array_ref: " << sizeof(buf) << '\n';
}
~~~
Array references carry the buffer size and enforce conformity.

~~~
test_array_ref: 1337
~~~
The output.

With an array reference the array length becomes part of the function
signature. That also enforces matching length, this is what happens
if the length mismatches:

~~~
test.cpp:25:2: error: no matching function for call to 'test_array_ref'
        test_array_ref(buf);
        ^~~~~~~~~~~~~~
test.cpp:11:6: note: candidate function not viable: no known conversion from 'char [1337]' to 'char (&)[1338]' for 1st argument
void test_array_ref(char (& buf)[1338]) {
     ^
~~~
Compilers complain about buffer size mismatches.

This is a great thing for correctness, but means a separate function
must be written for every supported array size. If it wasn't for
another C++ feature — template argument deduction:

~~~ c++
template <size_t BufSize>
void test_array_ref_tpl(char (& buf)[BufSize]) {
	std::cout << "test_array_ref_tpl: " << sizeof(buf) << '\n';
}
~~~
The BufSize is deduced implicitly.

~~~
test_array_ref_tpl: 1337
~~~
The output.

Coming Full Circle
------------------

And this is the cause for this error. The code was copied from an
environment where `sprintf()` was defined as:

~~~ c++
template <size_t Size, typename... Args>
inline int sprintf(char (& dst)[Size], const char * const format,
                   Args const... args) {
	return snprintf(dst, Size, format, args...);
}
~~~
A safety wrapper around `snprintf()`.

This templated version of `sprintf()` lets the compiler deal with
handing the buffer size to `snprintf()` getting rid of another source
of human error.

So what was perfectly safe and sound to do in this codebase became
a problem when copying the code into the article.

Conclusions
------------

Making `sprintf()` transparently safe was a bad idea. When reviewing
my code a reviewer would at least have to check the `using` declarations
to figure out that calling `sprintf()` doesn't mean calling the unsafe
C function.

In the spirit of explicit is better than implicit I'm renaming my
`sprintf()` function to `sprintf_safe()` and add this little morsel
of code:

~~~ c++
/**
 * This is a safeguard against accidentally using sprintf().
 *
 * Using it triggers a static_assert(), preventing compilation.
 *
 * @tparam Args
 *	Catch all arguments
 */
template <typename... Args>
void sprintf(Args...) {
	/* Assert depends on Args so it can only be determined if
	 * the function is actually instantiated. */
	static_assert(sizeof...(Args) && false,
	              "Use of sprintf() is unsafe, use sprintf_safe() instead");
}
~~~
Ensure compilation failure if someone tries to use `sprintf()`.

Also, if you are interested in C++, floating point arithmetics or
unicycles you should read [Bruce Dawson's blog][randomascii].
