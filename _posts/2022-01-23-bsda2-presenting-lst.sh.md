---
title:   "bsda2: Presenting LST.sh - A Portable Shell Array Library"
journal: 1
tags:
- shell-scripting
- programming
- BSDA2
---

[bsda2]:   https://github.com/lonkamikaze/bsda2
[LST.sh]:  https://github.com/lonkamikaze/bsda2/blob/master/src/lst.sh
[LST.md]:  https://github.com/lonkamikaze/bsda2/blob/master/ref/lst.md
[TYPE.sh]: https://github.com/lonkamikaze/bsda2/blob/master/src/type.sh
[TYPE.md]: https://github.com/lonkamikaze/bsda2/blob/master/ref/type.md
[tests]:   https://github.com/lonkamikaze/bsda2/blob/master/tests/lst.sh
{% include man.md p="bash" s=1 %}
{% include man.md p="sh" s=1 %}
{% include man.md p="ascii" s=7 %}
Unlike the [Bourne-Again Shell][`bash(1)`], the
[FreeBSD Almquist Shell][`sh(1)`] does not have native array support.
So for [bsda2] I have largely resolved to storing data in strings,
using the Line Feed character as a separator. Over time I have established
best practices for working with these strings, which some time last
year I decided to put into a small library - [LST.sh]. And like any
small project its exploded in my face ...

This article is not an introduction to the library as such (if you
are looking for that look at the [documentation][LST.md]). It's more
like a description of the journey and an account of the decisions
made along the way.

Scope
-----

As of this writing [210 lines of documentation][LST.md],
[642 lines of code and comments][LST.sh] and
[679 lines of tests][tests] do not look like all that much.
What really consumed most of my time was redesigning the interface
over and over again until I felt like I had struck a good bargain
between a concise and clear syntax.
At the same time the feature set exploded far past the originally
intended functionality.

Evolution of Design
-------------------

The name LST.sh is a direct result of my original use case not requiring
random access. Instead I always saw these strings as lists of data,
the main operations I require are:

1. Push new entries to the back
2. Iterate through the entire list
3. Pop something off the front of the list

### Once Upon a Time

When I started out doing this a list was a set of newline separated
entries:

```sh
list=$'item0\nitem1\nitem2'
```
Create `list` containing three entries.

<div class="note">
	<h4>Hint</h4>
	<p>
	The <code>$'text'</code> syntax interprets C-style character
	escape sequences such as <code>\n</code> to create a Line Feed
	character or <code>\r</code> to create the Carriage Return character.
	</p>
</div>

This is easy to iterate through:

```sh
local IFS
IFS=$'\n'
for entry in ${list}; do
	...
done
```
Iterate through `list`.

The code for pushing a new value is not as nice:

```sh
entry="item3"
list="${list}${list:+${IFS}}${entry}"
```
Push to the back.

<div class="note">
	<h4>Hint</h4>
	<p>
	The expression <code>${list:+${IFS}}</code> inserts
	<code>IFS</code> only if <code>list</code> is defined and
	not empty.
	</p>
</div>

Reading the first value is fine:

```sh
front="${list%%${IFS}*}"
```
Read the first entry.

<div class="note">
	<h4>Hint</h4>
	<p>
	The expression <code>${list%%pattern}</code> provides the
	value of list without the longest suffix matching the pattern.
	Equivalently <code>%</code> removes the shortest match and
	<code>#</code> and <code>##</code> remove matching prefixes.
	If the pattern does not match, the whole string is returned.
	</p>
	<p>
	Variables can be put in double quotes to ensure a literal
	match, this may be necessary if they contain glob pattern
	characters such as <code>?</code>, <code>*</code>, <code>[</code>
	or the <code>}</code> character. The behaviour of bash and sh
	may differ here, so if in doubt add quotes.
	</p>
</div>


Popping it off the front is two operations, because removing the
first value has to be separated from removing the separator, courtesy
of the last entry not being followed by a separator:

```sh
list="${list#"${front}"}"
list="${list#${IFS}}"
```
Pop the first entry off the list.

### The Current Style

This resulted in a simple change of style: every entry is followed
by a separator:

```sh
list=$'item0\nitem1\nitem2\n'
```
Create `list` containing three entries.

This simplifies pushing new entries to the back:

```sh
entry="item3"
list="${list}${entry}${IFS}"
```
Push to the back.

Iterating through the list or reading the first value does not change,
but popping a value off the front also got easier this way:

```sh
list="${list#*${IFS}}"
```
Pop the first entry off the list.

This is the model I set out to encode into a library.

### Error Handling

One feature that remained the same through all iterations of the code
is that there is no input validation. If inputs are invalid the script
may terminate or just silently ignore the problem. Input validation
is the callers' problem, minimising overhead is the design goal.

The return status of functions is used to handle expected cases instead,
such as popping from an empty array. Or simply as a true/false result
e.g. for the `contains()` function.

To verify inputs from untrusted sources, such as users or external
data sources, the [TYPE.sh] ([documentation][TYPE.md]) library can be used.

### Interface

The basic idea is to introduce a single function named `lst()` that
is an interpreter for the array/list syntax. Originally this function
was called directly and the implementation was hard coded to use the
Line Feed character as a separator.

But pretty early on I decided that it is a good idea to make the
separator configurable. I introduced the `RS` (Record Separator)
variable to configure the character. It can be set globally, or fed
to a single invocation specifically, e.g.:

```sh
RS=$'\n' lst ...
```
Call `lst()` using the Line Feed character as a separator.

Once again it's the callers' obligation to know which separator to
use with which array. For convenience `lst()` wrappers are provided
that call it with a specific `RS` value:

| Wrapper | ASCII Character  | `RS` Value   |
|---------|------------------|--------------|
| `log()` | Line Feed        | `RS=$'\n'`   |
| `rec()` | Record Separator | `RS=$'\036'` |
| `csv()` | Comma            | `RS=,`       |

Predefined `lst()` wrappers.

Making your own wrapper is simple:

```sh
fld() { RS=$'\034' lst "$@"; }
```
Use the Field Separator character as the Record Separator.

### Syntax

The earliest idea was to combine the name of the array with operator
to trigger a particular action:

```sh
rec list= item0 item1 item2
```
Initialise the array `list` with the entries `item0`, `item1` and `item2`.

In the first draft appending new items was done using the `+=` operator:

```sh
rec list+= item3
```
Append a new entry (not supported).

But I had to ask myself the question what would be a similarly intuitive
approach to prepend values? How do I pop a value off the front or
back? I experimented with adding new operators, which resulted in
a concise but confusing syntax.

In the end I settled on only five operators, the brunt of the functionality
is handled by the `.` operator:

```sh
rec list= item0 item1 item2
rec list.push_back  item3
rec list.push_front item-1
rec list.pop_front  entry  # = item-1
rec list.pop_back   entry  # = item3
```
As the number of *methods* grew I settled on clear over short names.

All *methods* are implemented as plain functions that take the name
of the array as the first argument. The `lst()` function is responsible
for translating the call.

Functions that return a string take a variable name argument to write
the string to. Because it is usually local name within the execution
context the `RS` variable cannot be written to. The same is sometimes
true for the variables `IFS`, `IRS` and `ORS` variables.

If the destination variable name is omitted the value is printed on
`stdout` instead.

### Random Access

Random access is one of those features I don't really need but it
is enticing and really nice during debugging sessions.

Random access is performed via the subscript operator `[]`:

```sh
rec list= item0 item1 item2
rec list[1]  entry # = item0
rec list[-1] entry # = item2
```
Random access from the front and back.

The array is indexed starting at 1, this was chosen over the customary
indexing starting at 0 to match function argument indexing and be
symmetrical with the reverse index syntax.

The index can be any arithmetic expression:

```sh
rec list= item0 item1 item2
i=0
while rec list[i-=1] entry; do
	echo "${entry}"
done # prints:
     # item2
     # item1
     # item0
```
Use an arithmetic expression to determine the index.

Calling `list[i]` without any additional operators is equivalent
to calling `list[i].get`. The assignment operator `list[i]=` is equivalent
to calling `lsit[i].set`. There also is a `list[i].rm` method, for
deleting an entry, which does not have a special operator to call it.

All these subscript methods are mapped to functions that take the
array name as the first and the index expression as the second argument.

### Using References

Because strings are returned by assigning them to a user provided
variable name, the use of local variables is effectively prohibited
(except for the reserved names `RS`, `IFS`, `IRS` and `ORS`, which
may not be referenced).
When intermediate values are a necessity they are thus stored in
the argument list via the `set --` command.

### Batch Operations

A nice convenience feature is batch operations, the push, pop and
rm methods can take multiple arguments to perform the operation
multiple times:

```sh
list=
rec list.push_back item0 item1 item2
```
This is equivalent to `rec list= item0 item1 item2`.

The push methods do not have a failure mode, but the pop or rm methods
do (no values left / no match). They stop performing the operation
on the first failure and the return value `$?` indicates for which
argument it failed:

```sh
rec list.rm_first item2 item3 item1 item0  # $? = 2
```
Fails to remove `item3`, does not process `item1` and `item0`.

This is a good example for discovering additional requirements by
implementing unit tests.

### Field Splitting and White Space

One trick of working with lists is using the shell's Field Splitting.
Such as to loop through all the values:

```sh
rec list.set_ifs
for entry in ${list}; do
	...
done
```
Loop through the array, using by using Field Splitting.

A simple method that makes use of this is the count method:

```sh
lst.count() {
	local IFS
	IFS="${RS}"
	eval "
	set -- \${$1}
	${2:-echo }${2:+=}\$#
	"
}
```
Expand the given array to a set of arguments using Field Splitting.

The count method expands the given array into positional arguments
and returns the argument count. This comes with a caveat, the shell
has special treatment for what it considers White Space characters.
I.e. all the characters in the default Input Field Separator set:
Space, Tab and Line Feed (`IFS=$' \t\n'`).

White Space characters in `IFS` are trimmed, making it impossible
to expand empty entries. This results in different behaviour of methods
making use of Field Splitting depending on whether the Record Separator
is a White Space character or not. The [documentation][LST.md] contains
a table, with a column indicating which methods and functions are
affected by this.

Alternative implementations for all of these functions are possible
but vastly more expensive, so I decided to just document the effect.
For many use cases it is not actually relevant, for some it is even
beneficial.

References
----------

* [LST.sh on GitHub][LST.sh]
* [LST.sh docs on GitHub][LST.md]
* [TYPE.sh on GitHub][TYPE.sh]
* [TYPE.sh docs on GitHub][TYPE.md]
  (GitHub Markdown has rendering problems with code in tables)
* [`sh(1)`]
* [`bash(1)`]
* [`ascii(7)`]
