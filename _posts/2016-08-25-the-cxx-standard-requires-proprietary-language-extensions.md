---
title: The C++ Standard Requires Proprietary Language Extensions
journal: 1
redirect_from:
- 2016/08/25/the-c++-standard-requires-proprietary-language-extensions
tag:
- C++
---

The `C++` standard consists of two parts. The language and the library.
The latter is built upon the first, or so I thought.

It starts with a fairly common pattern …
----------------------------------------

I have a couple of (strongly typed) enums, e.g:

~~~ c++
enum class EFoo { FOO0, FOO1 };
enum class EBar : size_t { BAR0, BAR1 };
~~~
Define `EFoo` and `EBar`

Occasionally I'd like to print the symbolic name of an `enum`, so
I made it a habit to create an array of character arrays.

~~~ c++
char const * const EFooStr[]{"FOO0", "FOO1"};
char const * const EBarStr[]{"BAR0", "BAR1"};
~~~
Symbolic names for enums

This allows me to print them, use them in exception messages, verbose
output etc.:

~~~ c++
EFooStr[static_cast<int>(EFoo::FOO0)];
~~~
Use an enum as an array index to retrieve a character array

There are other legitimate uses of casting an enum to its value type,
including returning the value from the main function, and when using
pre-C++11 or C interfaces.

Because writing `static_cast<TYPE>(ENUM)` becomes annoying and requires
looking up the value type I started to define an overload for `to_value()`
for each enum class:

~~~ c++
constexpr int to_value(EFoo const op) {
	return static_cast<int>(op);
}
constexpr size_t to_value(EBar const op) {
	return static_cast<size_t>(op);
}
~~~
Define a `to_value()` overload for each enum class

This makes the lookup less verbose without hiding that type cast/conversion
is happening:

~~~ c++
EFooStr[to_value(EFoo::FOO0)];
~~~
A less annoying way of casting an enum to the underlying value type

Simplifying
-----------

However adding an overload for each enum seems excessive and redundant
to me, so I tried to use my imagination to come up with a function
template that works for all enums:

~~~ c++
template <class ET, typename VT>
constexpr VT to_value(ET : VT const op) {
	return static_cast<VT>(op);
}
~~~
My best idea (not legal C++ code!)

Unfortunately this isn't legal C++ code in C++11 or C++14. However
there is a way of doing it, after failing I googled the problem and
came up with the `std::underlying_type` trait:

~~~ c++
#include <type_traits>
template <class ET, typename VT = typename std::underlying_type<ET>::type>
constexpr VT to_value(ET const op) {
	return static_cast<VT>(op);
}
~~~
Using a meta function to extract the underlying value type

After failing to come up with my own solution I had thought a meta
function like that would be impossible, but clearly I was wrong. I
spent another hour trying to come up with a meta programming trick
to implement my own `underlying_type` meta function until I gave
up and looked it up in the code of the standard library.

It turned out, the library cheats:

~~~ c++
template <class _Tp>
struct underlying_type
{
    typedef _LIBCPP_UNDERLYING_TYPE(_Tp) type;
};
~~~
No meta programming here

The meta function is just a wrapper around a proprietary compiler
feature
([Clang Language Extenstions](http://clang.llvm.org/docs/LanguageExtensions.html#checks-for-type-trait-primitives)):

> - `__underlying_type(type)`: Retrieves the underlying type for a given
>   enum type. This trait is required to implement the C++11 standard
>   library.

Conclusion
----------

So the standard provides a way of accessing the underlying type of
a strongly typed enum through the library, but the language does
not provide a way to implement the library.

This is not really a problem, but it's certainly undesirable.
