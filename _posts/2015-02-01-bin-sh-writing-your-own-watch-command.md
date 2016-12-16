---
title: "/bin/sh: Writing Your Own watch Command"
journal: 1
update: 2016-07-20
tags:
- shell-scripting
- FreeBSD
---

The command `watch` in FreeBSD has a completely different function
than the popular GNU-command with the same name. Since I find the
GNU-`watch` convenient I wrote a short shell-script to provide that
functionality for my systems. The script is a nice way to show off
some basics as well as some advanced shell-scripting features.

{% include man.md p="watch" s=8 %}
{% include man.md p="tput" s=1 %}
{% include man.md p="terminfo" s=5 %}

<div class="note">
	<h4>Note</h4>
	<p>
		As part of the move
		<a href="https://angryswarm.blogspot.com/2015/02/binsh-writing-your-own-watch-command.html">from blogger</a>,
		this article was updated {{ page.update }} to a version
		of the script that handles the <code>HUP</code> signal
		properly and causes less terminal flicker.
	</p>
</div>

To resolve the ambiguity with [`watch(8)`] I called it `observe` on
my system. My `observe` command takes the time to wait between updates
as the first argument. Successive arguments are interpreted as commands
to run. The following listing is the complete code:

~~~ sh
#!/bin/sh
set -f
sleep=$1
clear=
shift

runcmd() {
	local IFS line
	IFS='
'
	tput cm 0 0
	output="$(eval "$@")"
	for line in $output; do
		echo -n $line
		tput ce
		echo
	done
	tput cd
}

trap 'runcmd "$@"; tput ve' EXIT
trap 'exit 0' INT TERM HUP
trap 'clear=1' INFO WINCH

tput vi
clear
runcmd "$@"
while sleep $sleep; do
        eval ${clear:+clear;clear=}
        runcmd "$@"
done
~~~
The complete `observe` script.

Careful observers may notice that there is no parameter checking and
the code is not commented. These shortcomings are part of what makes
it a convenient example in a tutorial.

Turning Off Glob-Pattern Expansion
----------------------------------

The second line already shows a good convention:

~~~ sh
#!/bin/sh
set -f
~~~
Turn off glob pattern expansion.

The `set` builtin can be used to set parameters as if they were provided
on the command line. It is also able to turn them off again, e.g. `set +x`
would turn off tracing. The `-f` option turns off glob pattern expansion
for command arguments. This is a good habit to pick up, glob pattern
expansion is very dangerous in scripts. Of course the `-f` option
could be set as part of the shebang, e.g. `#!/bin/sh -f`, but that
would allow the script user to override it. By calling
`bash ./observe 2 ccache -s` the shell could be invoked without setting
the option, which is dangerous for options with safety-implications.

Global Variable Initialisation
------------------------------

The next block initialises some global variables:

~~~sh
sleep=$1
clear=
shift
~~~
Set up globals and shave off the first command line argument.

Initialising global variables at the beginning of a script is not
just good style (because there is one place to find them all), it
also protects the script from whatever the caller put into the environment
using `export` or the interactive shell's equivalent.

The `shift` builtin can be a very useful feature. It throws away the
first argument, so what was `$2` becomes `$1`, `$3` turns into `$2`
etc.. With an optional argument the number of arguments to be removed
can be specified.

The `runcmd` Function
---------------------

The `runcmd` function is responsible for invoking the command in a
fashion that overwrites its last output:

~~~ sh
runcmd() {
	local IFS line
	IFS='
'
	tput cm 0 0
	output="$(eval "$@")"
	for line in $output; do
		echo -n $line
		tput ce
		echo
	done
	tput cd
}
~~~
Execute the list of commands and carefully print the output.

The [`tput(1)`] command is handy to directly *talk* to the terminal.
What it can do depends on the terminal it is run in, so it is good
practice to test it in as many terminals as possible. A list of available
commands is provided by the [`terminfo(5)`] manual page. The following
commands were used here:

`cm`
: `cursor_address #row #col`
: Used to position the cursor in the top-left corner

`ce`
: `clr_eol`
: Clear to end of line

`cd`
: `clr_eos`
: Clear to end of screen

The `eval "$@"` command executes all the arguments (apart from the
one that was shifted away) as shell commands. The command is executed
in a subshell. That effectively prevents it from affecting the script.
It is not able to change signal handlers or variables of the script,
because it is run in its own process.

The following `for line` block prints the output line by line and
clears trailing characters after each line. Of course clearing the
screen and printing everything at once is faster, but it would introduce
flickering.

Signal Handlers
---------------

Signal handlers provide a method of overriding the shell's default
actions. The `trap` builtin takes the code to execute as the first
argument, followed by a list of signals to catch. Providing a dash
as the first argument can be used to invoke the default action:

~~~ sh
trap 'runcmd "$@"; tput ve' EXIT
trap 'exit 0' INT TERM HUP
trap 'clear=1' INFO WINCH
~~~
Handle signals.

`EXIT` is a pseudosignal that occurs when the shell terminates, i.e.
by reaching the end of the script (in this case if sleep would fail)
or an `exit` call.

The `INT` signal represents a user interrupt, usually caused by the
user pressing `CTRL+C`. The `TERM` signal is a request to terminate.
E.g. it is sent when the system shuts down. The `HUP` signal is sent
when the terminal is closed.

`WINCH` occurs when the terminal is resized. The `INFO` signal is
a very useful BSDism. It is usually invoked by pressing `CTRL+T` and
causes a process to print status information.

The Output Cycle
----------------

The output cycle heavily interacts with the signal handlers:

~~~ sh
tput vi
clear
runcmd "$@"
while sleep $sleep; do
        eval ${clear:+clear;clear=}
        runcmd "$@"
done
~~~
The main loop.

The `tput vi` command hides the cursor, `tput ve` in the `EXIT` handler
turns it back on.

The `clear` command clears up the terminal before the command is run
the first time.

The `runcmd "$@"` call occurs once before the loop, because the first
call within the loop occurs after the first `sleep` interval.

The `clear` **global** is set by the `WINCH`/`INFO` handler. The
`eval ${clear:+clear;clear=}` line runs the `clear` **command** if
the variable is set and resets it afterwards. The `clear` command
is not run every cycle, because it would cause flickering. The ability
to trigger it is required to clean up the screen in case a command
does not override all the characters from a previous cycle.

Conclusion
----------

If you made it here, thank you for reading this till the end! You
probably already knew a lot of what you read. But maybe you also learned
a trick or two. That's what I hope.
