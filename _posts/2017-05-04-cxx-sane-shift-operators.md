---
title:   "C++: Sane Shift Operators"
journal: 1
tag:
- C++
- tutorial
---

{% include cpplang.md f="operator_arithmetic#Bitwise_shift_operators" %}
{% include cpplang.md f="constexpr" %}
{% include cpplang.md f="class_template_deduction" %}
{% include hpp.md h="type_traits" %}
{% include cpp.md h="type_traits" m="make_unsigned" %}
{% include hpp.md h="climits" %}
[Bitwise shift operators] in C++ are wrought with perils. Undefined
behaviour awaits those shifting negative integers or shifting too
far, shifting by a negative number is implementation defined, which
means the compiler cannot just pretend it didn't happen or format
your hard drive, but you still don't have any guarantees about what
exactly you get.

<div class="note">
	<h4>Note</h4>
	<p>
	If you just want to grab the proposed code, go ahead to the
	<a href="#tldr">TL;DR</a> section.
	</p>
</div>

The Issue by Example
--------------------

At the moment I am experimenting with implementing fixed precision
numbers and a set of trigonometric functions, which requires a fair
amount of bit shifting logic, e.g.:

```c++
foo << (bar - x)
```
A deceptively simple bit shift operation.

Let's say we don't always know if `x` is always less then `bar`:

```c++
// foo << (bar - x)
bar >= x ? foo << (bar - x) : foo >> (x - bar);
```
Eliminate negative shift.

Now let's assume `foo` is an `int` and may be negative, we need to
cast `foo` to `unsigned int` to achieve defined behaviour:

```c++
// foo << (bar - x)
static_cast<int>(bar >= x
                 ? static_cast<unsigned int>(foo) << (bar - x)
                 : static_cast<unsigned int>(foo) >> (x - bar));
```
Eliminate negative integer shift.

So now we have covered two of the problematic cases, one more to go.
Assume `x` may get very big:

```c++
// foo << (bar - x)
static_cast<int>(bar >= x
                 ? static_cast<unsigned int>(foo) << (bar - x)
                 : (x - bar >= sizeof(int) * 8 ? 0
                    : static_cast<unsigned int>(foo) >> (x - bar)));
```
Eliminate whole integer shift.

Of course the same should be done for great values of bar, but at
this point we have seen everything we need to. Our little expression
`foo << (bar - x)`, which is fairly simple and completely expresses
what we want, has turned into something ugly in deed.

The Proposal
------------

The solution I am offering you is a function named `shift()`
that applies all this sanity code *magically*:

```c++
shift(foo) << (bar - x)
```
The `shift()` function makes its argument safely shiftable.

This magical function maintains the expressiveness of the `<<` operator,
unlike more obvious solutions like:

```c++
lshift(foo, bar - x)
```
A plain function to shift a value left.

```c++
rshift(foo, x - bar)
```
The equivalent right shift version.

Writing the Code
----------------

The idea is to create a wrapper type around integers, that is designed
to be eliminated from runtime code by the compiler. To achieve that
[constexpr] functions and construction will be used exclusively.
That means all our code must be visible, so the entire code should
be implemented within a header file.

### Constructing the Wrapper

To get started we define a class `shift_wrapper` and with its constructor:

```c++
template <typename IntT>
class shift_wrapper {
	private:
	IntT const value;

	public:
	constexpr shift_wrapper(IntT const value) : value{value} {}
	// more to come …
};
```
A constructible wrapper type.

The code to instantiate the wrapper looks like this:

```c++
shift_wrapper<decltype(foo)>{foo}
```
Wrapping `shift_wrapper` around `foo`.

I promised something a lot more simple and we will take care of this
first. By wrapping a function around the construction template argument
deduction can be used:

```c++
template <typename IntT>
constexpr shift_wrapper<IntT> shift(IntT const value) {
	return {value};
}
```
Wrap construction into a function to use template argument deduction.

Now the type can be applied as promised:

```c++
shift(foo)
```
Wrapping `shift_wrapper` around `foo`, the nice way.

Note that C++17 will permit [class template deduction] for constructors,
which will make this kind of thing obsolete, just rename `shift_wrapper`
to `shift` and you are set.

### Elminating Signedness

Working on signed values is all kinds of trouble, so instead use
[`std::make_unsigned`] to derive the unsigned version of the given
integer type:

```c++
#include <type_traits> /* std::make_unsigned */

template <typename IntT>
class shift_wrapper {
	private:
	using UIntT = typename std::make_unsigned<IntT>::type;
	UIntT const value;
	public:
	constexpr shift_wrapper(IntT const value) :
	    value{static_cast<UIntT>(value)} {}
	// more to come …
};
```
Derive `UIntT` from `IntT` and convert the given value in the constructor.

### Overloading `operator <<` and `operator >>`

The next step is overloading the operators. The key idea here is to
perform the bit shift and return the result as an `IntT` instead
of returning a self-reference. I.e. the wrapper does not stick around,
but discards itself after having been used.

Also note that the value member is private, shifting will be the only
way of getting the value back out of the wrapper.

Add the operators to the body of `shift_wrapper`:

```c++
constexpr IntT operator <<(int const bits) const {
	return static_cast<IntT>(this->value << bits);
}

constexpr IntT operator >>(int const bits) const {
	return static_cast<IntT>(this->value >> bits);
}
```
Naive implementations of the bit shift operators.

#### Invalid Shifts

Finally we just need to apply our safety regulations to the number
of bits we are shifting.

First we add a `bitsof()` function that is supposed to be a per bit
equivalent to `sizeof()`:

```c++
#include <climits>     /* CHAR_BIT */

template <typename T>
constexpr int bitsof() { return sizeof(T) * CHAR_BIT; }
```
The `bitsof()` function returns the number of bits of a type.

The `CHAR_BIT` macro contains the number of bits in a char, which is
8 on every platform I have ever used, but not on every platform that
has ever been or will ever be, so this is just a little cleaner than
writing 8 here.

The cases to handle here are `bits < 0` and `bits >= bitsof<IntT>()`:

```c++
constexpr IntT operator <<(int const bits) const {
	if (bits < 0) {
		return *this >> (- bits);
	}
	if (bits >= bitsof<IntT>()) {
		return 0;
	}
	return static_cast<IntT>(this->value << bits);
}

constexpr IntT operator >>(int const bits) const {
	if (bits < 0) {
		return *this << (- bits);
	}
	if (bits >= bitsof<IntT>()) {
		return 0;
	}
	return static_cast<IntT>(this->value >> bits);
}
```
The final operator implementation.

The above code is valid C++14, but not C++11. Using the ternary `?:`
operators it can easily be converted though.

Conclusions
-----------

Constexpr functions are more or less inline functions on roids.
They guarantee that they can be used at compile time, i.e. you can
use them in template definitions or `static_assert()`.

They also are implicitly inline functions and on any optimisation
level above `-O1` all the code should be inlined allowing the compiler
to eliminate code based on the properties of the target platform and
based on knowledge about the values.

E.g. in my use case the bits to shift depend on template arguments,
so the exact values are known at compile time, which will remove all
the conditionals and just leave a shift by a fixed number in place
or even substitute the whole expression with 0.

Of course this technique of using a temporary type to redefine certain
operators has more uses than enforcing well defined behaviour. E.g.
you can implement multiple types, realising different behaviours like
rotating bit shift etc.. Its use is also very explicit without being
overly verbose, so it strikes a fine balance between convenience and
not springing any surprises on your fellow coder.

Finally you probably want to wrap this in a namespace and sprinkle
some documentation over it. I usually have a hard time moving on
to my next task until I have documented the interface I'm leaving
behind completely.

References
----------

- [bitwise shift operators]
- [constexpr]
- [class template deduction]
- [`std::make_unsigned`] from [`<type_traits>`]
- `CHAR_BIT` from [`<climits>`]

TL;DR
-----

```c++
#include <type_traits> /* std::make_unsigned */
#include <climits>     /* CHAR_BIT */

template <typename T>
constexpr int bitsof() { return sizeof(T) * CHAR_BIT; }

template <typename IntT>
class shift_wrapper {
	private:
	using UIntT = typename std::make_unsigned<IntT>::type;
	UIntT const value;

	public:
	constexpr shift_wrapper(IntT const value) :
	    value{static_cast<UIntT>(value)} {}

	constexpr IntT operator <<(int const bits) const {
		if (bits < 0) {
			return *this >> (- bits);
		}
		if (bits >= bitsof<IntT>()) {
			return 0;
		}
		return static_cast<IntT>(this->value << bits);
	}

	constexpr IntT operator >>(int const bits) const {
		if (bits < 0) {
			return *this << (- bits);
		}
		if (bits >= bitsof<IntT>()) {
			return 0;
		}
		return static_cast<IntT>(this->value >> bits);
	}
};

template <typename IntT>
constexpr shift_wrapper<IntT> shift(IntT const value) {
	return {value};
}
```
A complete implementation.
