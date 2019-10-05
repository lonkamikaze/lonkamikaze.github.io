---
title:   "Embedded C++: Singletons"
journal: 1
tag:
- C++
- embedded
- tutorial
---

I develop C++ code for embedded devices, my work recently inspired
me to start what hopefully will become an embedded C++ miniseries.

Embedded C++ frequently deals with the physical world, as such hard
constraints are known during development and can be reflected in
the code. Famously [MISRA] C++ states that the heap shall not be
used. Which directly forces the compliant embedded developer to use
these constraints (e.g. to create permanent objects in global/static
memory) instead of pretending that memory is an unlimited commodity
(which is what the freestore/heap allows us to do).

The most common and simple version of this is the singleton. This
is a tale of all the woes to avoid in order to get it right.

[MISRA]:   https://www.misra.org.uk/
[SMBooks]: https://www.aristeia.com/books.html
[CRTP]:    https://en.wikipedia.org/wiki/Curiously_recurring_template_pattern

Creating a Singleton
--------------------

[Scott Meyers' Effective C++ Third Edition][SMBooks], item 4 describes
the core issue that affects singletons and its solution. Namely
*global object initialisation* and *static local initialisation*.

In the good old days of writing C (platform specific hooks aside) all
code was run from `main()`. Global objects were primitives, pointers
and aggregates (structs) and would have their initial values assigned
by the time `main()` was executed:

~~~ c++
// global_data.h
struct global_data {
	int foo;
	int bar;
	…
};

extern global_data g_data;

// global_data.c
struct global_data g_data{1, 2, …};
~~~
Global data C style.

Life as a C++ developer is a little more complicated. Global objects
are still initialised before `main()` is called. However objects
may have constructors that run user code. I.e. user code is running
before `main()` and may access other global objects before their
initialisation is performed.

### Local Static Initialisation

The common wisdom, by which I mean the wisdom proclaimed by Scott
Meyers, is to create global objects using local static initialisation:

~~~ c++
// MySingleton.hpp
class MySingleton {
	public:
	static MySingleton & instance() {
		static MySingleton singleton{};
		return singleton;
	}
	…
};
~~~
A singleton created by static local initialisation.

This implementation makes use of the language guarantee that static
function variables are initialised the first time the function block
containing them is entered. So the construction of the singleton
is deferred until `MySingleton::instance()` is called and completed
by the time `MySingleton::instance()` returns. Any object depending
on it must go through the `MySingleton::instance()` function, so
there is no way to access the singleton before it is initialised.

C++11 even mandates this must be thread safe. So this is pretty
much a fool proof solution - unless circular dependencies are involved.

Of course it has drawbacks, every call of instance() acquires a lock 
and checks the hidden boolean that determines whether the singleton
has already been initialised. This may or may not be expensive, it
depends on the platform and the compiler.

This can be mitigated by depending objects taking the reference and
storing it:

~~~ c++
// MyClass.hpp
class MySingleton;

class MyClass {
	public:
	MyClass();

	private:
	MySingleton & mySingleton;
};

// MyClass.cpp
#include "MyClass.hpp"
#include "MySingleton.hpp"

MyClass::MyClass() : mySingleton{MySingleton::instance()} {}
~~~
Aggregating a singleton instance.

This gives `MyClass` its own unguarded reference, which is still
safe to use, because it was acquired through the guarded function
and the memory location of an object with global storage cannot change
(local statics have global storage but local access).
This is a form of aggregation, a more general approach would be to
take the reference as an argument to the constructor.

Pointer Fallacies
-----------------

I have seen several imitations of this design, that get it just a
little wrong.

### The Raw Pointer Singleton

A common occurrence of this is the raw pointer singleton:

~~~ c++
// MySingleton.hpp
class MySingleton {
	public:
	static MySingleton * instance();
	private:
	static MySingleton * singleton;
};
~~~
The raw pointer singleton interface.

The first thing that looks wrong here is that `MySingleton::instance()`
returns a pointer. This is not strictly a bug, but it is an unnecessary
burden nonetheless. References guarantee that they always point to
valid, initialised memory. This interface does not. Instead, the
caller must always check if the returned pointer is a `nullptr`.

The runtime cost of checking a pointer is usually near zero, but
it does clutter the code and sometimes pointer checks break when
code is refactored.

A greater cause of concern is `MySingleton::singleton`. Take this
implementation lifted from real world code:

~~~ c++
// MySingleton.cpp
#include "MySingleton.hpp"

MySingleton * MySingleton::singleton = nullptr;

MySingleton * MySingleton::instance() {
	if (singleton == nullptr) {
		singleton = new MySingleton{};
	}
	return singleton;
}
~~~
The raw pointer singleton implementation.

This example suffers from a subtle problem. `MySingleton::instance()`
might be called before `MySingleton::singleton` is initialised. Accessing
uninitialised memory is undefined behaviour so all bets are off any
way.

But this may go wrong in multiple non-theoretical fashions:

- The pointer happens to be non-null memory
  1. A bogus pointer is returned
  2. The caller dereferences the pointer
  3. Undefined behaviour ensues
- The pointer happens to be null memory
  1. A `MySingleton` instance is created on the freestore (heap)
  2. The caller dereferences the pointer
  3. Nothing bad happens
  4. `MySingleton::singleton` is initialised (overwritten with nullptr)
  5. `MySingleton::instance()` is called again
  6. A new instance is created and a pointer to that returned
  7. Now there are two instances of the singleton around

There is a way none of this happens, if the compiler knows in advance
that memory is zero-initialised it may eliminate the initialisation
of `MySingleton::singleton`. In this case all calls of
`MySingleton::instance()` return the same pointer, however the first
call still is a case of undefined behaviour. I.e. this is not to
be relied upon.

### The `std::unique_ptr` Singleton

The modern variant of this is an implementation based on `std::unique_ptr`:

~~~ c++
// MySingleton.hpp
#include <memory>

class MySingleton {
	public:
	static MySingleton * instance();
	private:
	static std::unique_ptr<MySingleton> singleton;
};

// MySingleton.cpp
#include "MySingleton.hpp"

std::unique_ptr<MySingleton> MySingleton::singleton = nullptr;

MySingleton * MySingleton::instance() {
	if (singleton == nullptr) {
		singleton = std::make_unique<MySingleton>();
	}
	return singleton.get();
}
~~~
The `std::unique_ptr` singleton interface.

One might assume that this fixes at least the potential memory leak
problem, because `std::unique_ptr` deletes previously owned objects
on assignment. But this is not the case, because it is constructed,
not assigned to. And a constructor must not check its members for
preexisting values before initialising them, because accessing uninitialised
memory invokes undefined behaviour.

### A Freestore (Heap) Singleton

The only correct way of putting a singleton on the freestore is to
use static local initialisation for the pointer:

~~~ c++
// MySingleton.hpp
class MySingleton {
	public:
	static MySingleton * instance();
};

// MySingleton.cpp
#include "MySingleton.hpp"
#include <memory>

MySingleton * MySingleton::instance() {
	static auto const singleton = std::make_unique<MySingleton>();
	return singleton.get();
}
~~~
The freestore based singleton.

This is free of undefined behaviour, but I can conceive only one
reason to do this over the canonical by reference design - using
a custom allocator to place an object into a special memory location.
Usually there are better ways to do this, though.

Conclusions
-----------

In a team with different skill sets it might be a good idea to solve
the singleton issue in a generic way.

The *Curiously Recurring Template Pattern* (CRTP) makes it possible
to access methods of a derived class without relying on virtual functions
(which cannot be used to construct an object any way):

~~~ c++
// singleton_type.hpp
template <class DerivedT>
struct singleton_type {
	static DerivedT & instance() {
		static DerivedT singleton{};
		return singleton;
	}

	bool is_singleton() const { return this == &instance(); }
};
~~~
A generic singleton facility.

This template can be used to add the singleton property to any class:

~~~ c++
// MySingleton.hpp
#include "singleton_type.hpp"

class MySingleton : public singleton_type<MySingleton> {
	…
};
~~~
Using the generic singleton facility.

Fun fact, if you google for the CRTP pattern you will find a stackoverflow
entry that uses singletons as an example. It's unfortunately one of
the broken singleton implementations.
I recommend the [Wikipedia article on CRTP][CRTP], though.

References
----------

- [Scott Meyers' books][SMBooks]
- [Curiously recurring template pattern (Wikipedia)][CRTP]
