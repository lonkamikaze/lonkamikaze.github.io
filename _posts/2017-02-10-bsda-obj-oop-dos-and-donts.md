---
title:   "bsda:obj: Object Oriented Programming Dos and Don'ts"
journal: 1
tags:
- shell-scripting
- programming
- BSDA2
---

[bsda]:        http://bsdadminscripts.sf.net
[ebsd2010]:    http://2010.eurobsdcon.org/presentations-schedule/paper-detail-view/?tx_ptconfmgm_controller_detail_paper[uid]=17&tx_ptconfmgm_controller_detail_paper[pid]=299
[bsda2]:       https://github.com/lonkamikaze/bsda2
[bsda:obj]:    https://github.com/lonkamikaze/bsda2/blob/master/bsda_obj.md
[bsda2-0.1.0]: https://github.com/lonkamikaze/bsda2/releases/tag/0.1.0
[bsda_obj.sh]: https://raw.githubusercontent.com/lonkamikaze/bsda2/master/src/bsda_obj.sh
Once upon a time I wrote an OOP framework for shell scripts and in
2010 I even presented it at [EuroBSDCon][ebsd2010]. Originally I was
going to use [bsda:obj], the OOP shell scripting framework, to rewrite
the `bsdadminscripts`. By now they have been rotting, mostly long
obsolete and abandoned, [on sourceforge][bsda].
However a couple of the tools therein remain popular, which finally
got me to recode and [release them][bsda2-0.1.0]. Post-release I've
started cleaning up `bsda:obj` so I would like to share a couple of
lessons I've learned and applied over the years.

The most interesting part of this article is probably the section
[New Features](#new-features), so skip ahead if you feel impatient.

Quick Intro
-----------

The `bsda:obj` framework introduces the concept of classes into shell
scripting. It is neither the first nor last project to do so, but it
does so in a useful manner and tries to find a usable balance between
overhead and convenience.

Originally this section was supposed to give a quick and dirty intro,
but it grew way too big. If you want to have a look, you need [bsda_obj.sh]
and the [manual][bsda:obj].

Feature Cruft
-------------

The [bsda:obj] framework started in 2009. Back then my idea of what
features a language needs to build useful abstractions was very much
shaped by Java. A lot has happened since then (like C++11) and with
all the experience I gained my idea of what an ideal language constitutes 
has grown far apart from Java. This is reflected in the changes I
made.

### Inheritance

Inheritance can be useful to facilitate code reuse, but what I really
wanted was polymorphism (the ability to have one thing stand in for
another). In strongly typed languages inheritance is usually a requirement
for polymorphism. Except that this isn't necessarily so. Polymorphism
in weakly typed languages like python is just a matter of providing
the required parts of an interface.

Similar things can be said about C++. Due to its C roots, where polymorphism
has to be achieved by erasing type information, C++ is not strictly
strongly typed. But thanks to inheritance you can achieve polymorphism
without erasing (all) type information. Also with templates the language
offers a compile time polymorphism that does not require inheritance,
yet is strongly typed.
Inheritance has its uses as a tool to avoid code duplication in both
python and C++, but over the years I noticed I don't use it very much.
In fact, in C++ most of the time I use inheritance I'm using it for
some meta-programming shenanigans.

Also there is a tool that often can make inheritance obsolete: *composition*.
In fact when looking at C++ inheritance in a debugger it turns out
that the compilers implement inheritance via composition!

So I decided to cut inheritance from `bsda:obj` and to my surprise
everything still worked. It turned out that I had already replaced
all the code that made use of it. This reduced the complexity of
`bsda:obj` enormously and I didn't loose a thing.

### More Cuts

Other features were cut as well:

#### `reset()`

The idea behind a `reset()` method was to facilitate reusing resources
to save runtime or transparently replacing an object that is referenced
from somewhere else.
`Bsda:obj` puts a lot of plumbing in place when creating an instance
of a class. Tearing it all down and recreating it to create a new
object seemed like a bad idea at the time.

So the `reset()` method simply cleared all attributes and you were
ready to go with a virgin object. This is fine for plain old data
(POD), but not a good idea for anything holding resources, which
would of course leak when calling `reset()`.

So I decided that it's better to let the user handle this by calling
the cleanup and init methods manually.

#### `serialiseDeep()`

The `serialiseDeep()` method was originally built into `bsda:obj`
to serialise a dependency tree. However without a type system that
entailed grepping through all attributes for things looking like
object references and recursively performing the same thing on those
objects references.

The whole thing was a big, ugly, barely maintainable mess and slow
to boot. So it was kicked to the curb.

#### Interfaces

That was an idea carried over from Java, it basically added complexity
to `bsda:obj` without providing any benefits whatsoever.


New Features
------------

After the cleanup was mostly done, I started adding features. The
focus this time was adding features that help me avoid leaking resources.

Resources, I would like to stress at this point, are not just memory,
but also things like locks, temporary files, forked processes etc.
Things that do not go away when the process terminates.

Those are the kind of leaks not even garbage collection can prevent
and shell scripts are no exception to this problem.

### Safer `copy()` and `serialise()`

So after kicking out the more dangerous default methods I was left
with `copy()` and `serialise()`. I did not want to get rid of them,
but they also have the potential to create problems.

E.g. consider a class, which opens a new file descriptor and closes
it in its cleanup method (a cleanup method is a non-default destructor).

Create a copy of an instance and the original as well as the copy
will initially continue work. However if either one is deleted it
will close the file descriptor still in use by the other instance.

Or imagine you serialise an instance of a class that creates a temporary
file. Wherever or whenever you deserialise it, the temporary file
is probably not part of that environment.

This problem can easily be solved by borrowing a page from C++. Neither
method is created if an object has a non-default destructor. A non
default destructor implies that an object has some kind of outside
dependency that cannot be satisfied by simply copying all the data
over to the new object.

Where desired these methods can still be supplied manually, like the
[container classes](https://raw.githubusercontent.com/lonkamikaze/bsda2/master/src/bsda_container.sh)
do.

### RAII

{% include cpp.md h="memory" m="unique_ptr" %}
{% include cpp.md h="memory" m="shared_ptr" %}
RAII is short for Resource Acquisition Is Initialisation, which is
a design pattern to avoid leaks. This pattern is very popular among
C++ programmers and it means that every resource is acquired in a
constructor (when initialising an object) and freed in the corresponding
destructor.

E.g. [`std::unique_ptr`] and [`std::shared_ptr`] provide this as a
generalised pattern for heap memory.

In C++ such a resource holding object can be created on the stack,
where its destructor will automatically be called when the context
of the object is left. I.e. the resources are always freed, the programmer
no longer needs to consider all the cleanup that needs to be done
and can just `return` from anywhere in a function.

RAII can be used in garbage collected languages, too. In Java, where
everything is created on the heap this has the problem that freeing
those resources is deferred until the garbage collector catches up
with the resources handling object. This can be a problem, e.g. if
the resource is a lock.

[using directive]: http://stackoverflow.com/questions/75401/uses-of-using-in-c-sharp#75483
Other garbage collected languages offer workarounds for this problem.
E.g. C# provides the [using directive] to create a context where
a resource can be used and released when leaving that context.

`Bsda:obj` performs garbage collection when the process terminates.
This at least makes sure all resources are released when a script
terminates. This means calling `exit` from anywhere within a script
is safe but it does not solve leaking while the script is still running.

So in a new addition to `bsda:obj` I borrowed a page from C#'s book
and added `$caller.delete`:

~~~ bash
Foo.doSomething() {
	local array
	bsda:fifo:Array array
	$caller.delete $array
	
	$array.push …
	… do whatever you please …
}
~~~
Make resources temporary by calling `$caller.delete`.

The instruction `$caller.delete $x` means delete `$x` when returning 
to the caller. Adding this code right behind the instantiation of
an object makes it possible to return from anywhere within the function
without leaking the resource.

### Aggregation

In the section about [Inheritance](#inheritance) I mentioned that
often composition can replace inheritance. And composition also supports
scenarios where inheritance would be useless.

E.g. if you define a triangle you can compose it from 3 points. But
what would be the semantics of inheriting from a point thrice?

In C++ there is a clear technical distinction between composition
and aggregation. Composition means the composed objects occupy one
block of memory, whereas aggregations just own pointers or references
to the objects they bundle together.

In languages like Java or python only the second option is possible,
so the distinction becomes a semantic one, basically it is called
composition if the objects are tightly coupled and aggregation otherwise.
This was a matter of confusion to me until I grokked C++.

Aggregation was already wildly used everywhere in `bsda:obj`. But
I wanted it to be more like composition. However with composition
I would basically get a lot of the complexity back that I got rid
of by removing inheritance. So I opted with just making aggregation
more convenient:

~~~ bash
bsda:obj:createClass pkg:libchk:Session \
	a:private:Flags=bsda:opts:Flags \
	a:private:Term=bsda:tty:Async \
	a:private:Fifo=bsda:fifo:Fifo \
	i:private:init \
	…

pkg:libchk:Session.init() {
	# Setup terminal manager
	bsda:tty:Async ${this}Term
	# Create a flag container for command line arguments
	bsda:opts:Flags ${this}Flags
	# Create the fifo for inter-process I/O
	bsda:fifo:Fifo ${this}Fifo

	…
}
~~~
Using aggregations in `pkg_libchk`.

While aggregated objects still have to be manually instantiated,
usually but not necessarily from within a constructor, aggregations
in `bsda:obj` are now automatically deleted, copied and serialised
together.

The default `copy()` and `serialise()` methods for an aggregated
object only are created if all the objects that are part of an aggregation
have `copy()` and `serialise()` methods.

The class of an aggregation can be omitted in which case the aggregated
objects are still deleted together, but the `copy()` and `serialise()`
methods will not be created.

References
----------

- [GitHub repository][bsda2]
- [`Bsda:obj` manual][bsda:obj]
