---
title: "/bin/sh: Using Named Pipes to Talk to Your Main Process"
journal: 1
tags:
- shell-scripting
---

You want to fork off a couple of subshells and have them talk back
to your main Process? Then this post is for you.

{% include man.md p="mkfifo" s=1 %}
{% include man.md p="head" s=1 %}
{% include man.md p="ssh" s=1 %}
{% include man.md p="nc" s=1 %}

What is a Named Pipe?
---------------------

A named pipe is a pipe with a file system node. This allows arbitrary
numbers of processes to read and write from the pipe. Which in turn
makes multiple usage scenarios possible. his post just covers one
of them, others may be covered in future posts.

The Shell
---------

The following examples should work in any Bourne Shell clone, such
as the Almquist Shell (`/bin/sh` on FreeBSD) or the Bourne-Again Shell
(bash).

HowTo
-----

The first step is to create a named pipe. This can be done with the
[mkfifo(1)] command:

~~~ sh
# Get a temporary file name
node="$(mktemp -u)" || exit
# Create a named pipe
mkfifo -m0600 "$node" || exit
~~~
Creating a named pipe.

Running that code should produce a named pipe in `/tmp`.

The next step is to open a file descriptor. In this example a file
descriptor is used for reading and writing, this avoids a number of
pitfalls like deadlocking the script:

~~~ sh
# Attach the pipe to file descriptor 3
exec 3<> "$node"
# Remove file system node
rm "$node"
~~~
Create a file descriptor for the named pipe.

<div class="note warn">
	<h4>Warning</h4>
	<p>
		Note how the file system node of the named pipe is
		removed immediately after assigning a file descriptor.
		The <code>exec 3<> "$node"</code> command has opened
		a permanent file descriptor, which remains open until
		manually closed or until the process terminates. So
		deleting the file system node will cause the system
		to remove the named pipe as soon as the process terminates,
		even when it is terminated by a signal like <code>SIGINT</code>
		(user presses CTRL-C).
	</p>
</div>

### Forking and Writing into the Named Pipe

From this point on the subshells can be forked using the `&` operator:

~~~ sh
# This function does something
do_something() {
    echo "do_something() to stdout"
    echo "do_something() to named pipe" >&3
}

# Fork do_something()
do_something &
# Fork do_something(), attach stdout to the named pipe
do_something >&3 &

# Fork inline
(
    echo "inline to pipe" >&3
) &
# Fork inline, attach stdout to the named pipe
(
    echo "inline to stdout"
) >&3 &
~~~
Forking examples.

Whether output is redirected per command or for the entire subshell
is a matter of personal taste. Either way the processes inherit the
file descriptor to the named pipe. It is also possible to redirect
stderr as well, or redirect it into a different named pipe.

The named pipe is buffered, so all the subshells can start writing
into it immediately. Once the buffer is full, processes trying to
write into the pipe will block, so sooner or later the data needs
to be read from the pipe.

### Reading from the Named Pipe

To read from the pipe the shell-builtin command `read` is used.

<div class="note warn">
	<h4>Warning</h4>
	<p>
		Using non-builtin commands like
		{% include man.html p="head" s=1 %} usually leads
		to problems, because they may read more data from
		a pipe than they output, causing the data to be lost.
	</p>
</div>

~~~ sh
# Make sure white space does not get mangled by read (IFS only contains the newline character)
IFS='
'

# Example 1)
# Blocking read, this will halt the process until data is available
read -r line <&3

# Example 2)
# Non-blocking read that reads as much data as is currently available
line_count=0
lines=
while read -rt0 line <&3; do
    line_count=$((line_count + 1))
    lines="$lines$line$IFS"
done
~~~
Blocking and non-blocking read from the file descriptor assigned to
the named pipe.

Using a blocking read causes the process to sleep until data is available.
The process does not require any CPU time, the kernel takes care of
waking the process.

That's all that is required to establish ongoing communication between
your processes.

The direction of communication can be reversed to use the pipe as
a job queue for forked processes. Or a second pipe can be used to
establish 2-way communications. With just two processes a single pipe
might suffice for two way communications. A named pipe can be connected
to an [ssh(1)] session or [nc(1)].

Basically named pipes are a way to establish a pipe to background
processes or completely independent processes, which do not even have
to run on the same machine. So, happy hacking!
