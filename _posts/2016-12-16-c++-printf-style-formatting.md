---
title:   "C++: printf Style Formatting"
journal: 1
tag:
- C++
- tutorial
---

{% include man.md p="snprintf" s=3 %}
{% include cpp.md h="string"  m="string" %}
{% include cpp.md h="sstream" m="ostringstream" %}
{% include cpp.md h="memory"  m="unique_ptr" %}
{% include cpp.md h="utility" m="move" %}
{% include hpp.md h="string" %}
{% include hpp.md h="cstdio" %}
{% include hpp.md h="iostream" %}
The native way of formatting an [`std::string`] using the C++ standard
library is creating an [`std::ostringstream`] and streaming the formatting
flags and data into it. This can lead to surprisingly elegant solutions,
but often it is rather clunky.
For theses cases this article describes a simple abstraction for
[`snprintf(3)`], lifting it from an archaic C interface to something
that looks and feels like proper C++.

The includes used in the following listings are [`<string>`], [`<cstdio>`]
and [`<iostream>`]. Some more if the code that does not end up in
the final solution is taken into account. The includes are not shown
in the code listings.

Approach
--------

The basic idea is taking a string literal like `"Address of foo: %#04x\n"`
and enveloping it with a zero overhead wrapper. This wrapper can provide
operators to insert data into the formatting string.

Construction
------------

All the wrapper needs is a pointer to the literal and a simple `constexpr`
constructor:

~~~ c++
class Formatter {
	private:
	char const * const fmt;
	public:
	constexpr Formatter(char const * const fmt) : fmt{fmt} {}
};
~~~
All that is needed is a pointer to the string literal.

So far this doesn't do anything but holding the pointer.

What to Return
--------------

The [`snprintf(3)`] function takes a formatting string, the data to
insert and stuffs the result into a buffer. This buffer, containing
the formatted string should be returned. Two types are obvious matches:

- `std::unique_ptr<char[]>`
- `std::string`

Before deciding on a return type there is a compromise to make, CPU
cycles versus memory. This results from the circumstance, that the
size required for the buffer cannot be known *before* running `snprintf()`.

### Minimum Memory Footprint

The scenario requiring the smallest memory footprint is this:

~~~ cpp
char buf[1];
auto size = snprintf(buf, sizeof(buf), this->fmt, args...);
assert(size >= 0 && "size < 0 in case of encoding errors");
std::unique_ptr<char[]> resbuf{new char[size + 1]};
snprintf(resbuf.get(), size + 1, this->fmt, args...);
return std::move(resbuf);
~~~
Function body that returns ownership to a perfectly sized buffer.

So what happens here?

1. `snprintf()` is run and performs the formatting work, but doesn't
   write it into the buffer. It however tells us how many bytes the
   resulting string would have had.
2. Create a buffer with enough bytes for the whole string +1 for
   the terminating 0 character.
3. Rerun `snprintf()` to write the formatted string into the buffer.
4. Return (move) the buffer.

| Pros                     | Cons                       |
|--------------------------|----------------------------|
| smallest possible buffer | printf does its work twice |
| no buffer copy on return |                            |

Pros and cons of this approach.

### Minimum CPU Footprint

This should be the fastest in terms of CPU time consumed:

~~~ cpp
std::unique_ptr<char[]> buf{new char[4096]};
auto size = snprintf(buf, 4096, this->fmt, args...);
assert(size >= 0 &&   "size < 0 in case of encoding errors");
assert(size < 4096 && "size >= 4096 if the string did not fit");
return std::move(buf);
~~~
Function body that returns a 4 KiB buffer.

The approach here is to basically ask for a buffer that one hopes
is big enough, and return that.

| Pros                              | Cons             |
|-----------------------------------|------------------|
| single invocation of `snprintf()` | oversized buffer |
| no buffer copy on return          |                  |

Pros and cons of this approach.

### Compromise

~~~ cpp
char buf[16384];
auto size = snprintf(buf, sizeof(buf), this->fmt, args...);
assert(size >= 0 &&          "size < 0 in case of encoding errors");
assert(size < sizeof(buf) && "size >= sizeof(buf) if the string did not fit");
return std::string{buf, static_cast<size_t>(size)};
~~~
Function body that returns an std::string.

The compromise here is to create a fairly big buffer on the stack,
where it basically doesn't cost anything, thus there is wiggle room
for making it big enough for most use cases.

| Pros                              | Cons                       |
|-----------------------------------|----------------------------|
| single invocation of `snprintf()` | string is copied on return |
| minimum heap usage                |                            |

Pros and cons of this approach.

The core of this compromise is that the minimum memory footprint is
bought with a string copy. This costs more CPU time, than returning
the fixed size buffer of the previous approach, but is still far
cheaper than calling `snprintf()` twice (please send me your benchmarks).

Creating a buffer on the stack is fairly cheap, after all only the
used portion goes into the CPU cache. The only expected cost is that
`snprintf()` probably ends up on a different cache page.

Using [`std::string`] is a pretty obvious choice, because it comes
with a constructor that copies a given amount of data from a buffer.
So it doesn't need to inspect the string for a 0 byte (in fact the
string may contain 0 bytes). Because the string is a temporary object
(i.e. an rvalue), move semantics are invoked without calling [`std::move`]
explicitly.

The Operator
------------

One option to provide the `snprintf()` functionality would be to
provide a method for doing that. But the final usage scenario lends
itself to using an operator. Because of the need to provide an arbitrary
amount of arguments only one operator is available, the `()` operator.

Because the number of arguments is known at compile time, a variadic
template can be used:

~~~ cpp
template <typename... ArgTs>
std::string operator ()(ArgTs const &... args) const {
	…
}
~~~
Signature of the `operator ()` returning a formatted string.

Putting its definition into the class body allows the compiler to
inline the operator to eliminate the overhead of the function call
and moving the string (the string can be created in place).

Because what constitutes a sufficiently large buffer may change from
use case to use case, the buffer size should become a template argument
to the `Formatter` class. This allows creating a bunch of type aliases
for different scenarios:

~~~ c++
template <size_t BufSize>
class Formatter {
	private:
	char const * const fmt;
	public:
	constexpr Formatter(char const * const fmt) : fmt{fmt} {}

	template <typename... ArgTs>
	std::string operator ()(ArgTs const &... args) const {
		char buf[BufSize];
		…
	}
};

using Fmt1k = Formatter<1024>;
using Fmt4k = Formatter<4096>;
using Fmt16k = Formatter<16384>;
using Fmt64k = Formatter<65535>;
~~~
Formatter with tunable buffer size.

The final `operator ()` implementation looks like this:

~~~ cpp
template <typename... ArgTs>
std::string operator ()(ArgTs const &... args) const {
	char buf[BufSize];
	auto size = sprintf(buf, this->fmt, args...);
	if (size >= BufSize) {
		/* does not fit into buffer */
		return {buf, BufSize - 1};
	} else if (size < 0) {
		/* encoding error */
		return {};
	}
	return {buf, static_cast<size_t>(size)};
}
~~~
The operator completes the `Formatter` class/template.

Note the different handling of the error cases. The appropriate handling
of errors may well depend on the usage scenario and the confidence
of not triggering an error. In a library for 3rd party use it's probably
a good idea to throw exceptions in the error cases. This version was
picked because it generates less code than the asserts, but at least
nothing illegal/undefined happens.

At this point it is possible to use the formatter:

~~~ cpp
int main() {
	std::cout << Fmt1k{"Address of main(): %#04x\n"}(&main);
	return 0;
}
~~~
Using the formatter.

With sufficient optimisation (e.g. `-O2`) the class is completely
eliminated and the operator inlined, so there is no additional cost
over handling `snprintf()` use directly.

User-Defined Literals
---------------------

One last step to turn the formatter into a first class feature is
using user-defined literals instead of type aliases or typedefs:

~~~ cpp
constexpr Formatter<16384> operator "" _fmt(char const * const fmt, size_t const) {
	return {fmt};
}

int main() {
	std::cout << "Address of main(): %#04x\n"_fmt(&main);
	return 0;
}
~~~
Using a user-defined literal to create the Formatter.

Note that C++ combines a sequence of string literals into a single
one, which makes it easy to define large strings inline:

~~~ cpp
int main() {
	std::cout << "Knights Radiant:\n"
	             "|    ID | Name       | Order      |\n"
	             "|-------|------------|------------|\n"
	             "| %5d | %-10.10s | %-10.10s |\n"
	             "| %5d | %-10.10s | %-10.10s |\n"
	             "| %5d | %-10.10s | %-10.10s |\n"_fmt
	             (1, "Kaladin", "Windrunner",
	              2, "Shallan", "Lightweaver",
	              3, "Dalinar", "");
	return 0;
}
~~~
Inline formatting of multiline strings.

This generates the following output:

~~~
Knights Radiant:
|    ID | Name       | Order      |
|-------|------------|------------|
|     1 | Kaladin    | Windrunner |
|     2 | Shallan    | Lightweave |
|     3 | Dalinar    |            |
~~~
Verbatim output.

I rest my case.

References
----------

- [`snprintf(3)`]
- [`std::string`], [`std::ostringstream`]
- [`std::unique_ptr`], [`std::move`]
- [`<string>`], [`<iostream>`], [`<cstdio>`]
