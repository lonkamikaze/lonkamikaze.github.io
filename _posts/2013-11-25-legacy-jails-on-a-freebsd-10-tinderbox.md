---
title: Legacy Jails on a FreeBSD 10 Tinderbox
journal: 1
tags:
- FreeBSD
---
It has become customary to me to build libreoffice packages, whenever
an update is available in the ports tree. The packages are published
on the
[BSDForen.de Wiki](https://wiki.bsdforen.de/anwendungen:libreoffice_aus_inoffiziellen_paketen).
Recently I updated the Tinderbox host system to FreeBSD 10.

<div class="note warn">
	<h4>Disclaimer</h4>
	<p>
	This unfinished article has been sitting here for some time
	and was an attempt to keep track of my efforts to fix building
	legacy Tinderbox jails on FreeBSD 10. I have not made any
	progress for some time. So I decided to publish this article,
	maybe it is of use to someone else working on the same problems.
	</p>
</div>

The Error
---------

I use the oldest supported release for each branch to maximize the
number of people who can use the packages. I use `apply` to update
the whole batch of jails:

<pre>
# /usr/local/tinderbox/jails
# apply 'tc makeJail -j' *
8.3-amd64: updating jail with SVN
8.3-amd64: cleaning out /usr/local/portstools/tinderbox/jails/8.3-amd64/obj
8.3-amd64: cleaning out /usr/local/portstools/tinderbox/jails/8.3-amd64/tmp
8.3-amd64: making world
<span class="bad">ERROR: world failed - see /usr/local/portstools/tinderbox/jails/8.3-amd64/world.tmp</span>
Cleaning up after Jail creation.  Please be patient.
8.3-i386: updating jail with SVN
8.3-i386: cleaning out /usr/local/portstools/tinderbox/jails/8.3-i386/obj
8.3-i386: cleaning out /usr/local/portstools/tinderbox/jails/8.3-i386/tmp
8.3-i386: making world
<span class="bad">ERROR: world failed - see /usr/local/portstools/tinderbox/jails/8.3-i386/world.tmp</span>
Cleaning up after Jail creation.  Please be patient.
…
</pre>
Building 8.x jails fails.

So I checked the first log file `8.3-amd64/world.tmp`:

<pre>
--- upgrade_checks ---
A failure has been detected in another branch of the parallel make

make[1]: stopped in /usr/local/portstools/tinderbox/jails/8.3-amd64/src
*** [upgrade_checks] Error code 2

make: stopped in /usr/local/portstools/tinderbox/jails/8.3-amd64/src
1 error

make: stopped in /usr/local/portstools/tinderbox/jails/8.3-amd64/src
</pre>
More verbosity please!

FreeBSD 10 comes with a new version of make that has some incompatibilities.
The `-B` flag causes `make` to behave old-fashioned.

The next log turned out to be a lot more telling:

<pre>
…
c++ -O2 -pipe -I/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/legacy/usr/include -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf/../../../contrib/gperf/lib -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf -c /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf/../../../contrib/gperf/src/version.cc
c++ -O2 -pipe -I/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/legacy/usr/include -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf/../../../contrib/gperf/lib -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf -c /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf/../../../contrib/gperf/lib/getline.cc
c++ -O2 -pipe -I/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/legacy/usr/include -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf/../../../contrib/gperf/lib -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf -c /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/gperf/../../../contrib/gperf/lib/hash.cc
<span class="bad">make: don't know how to make /usr/lib/libstdc++.a. Stop</span>
*** Error code 2

Stop in /usr/local/portstools/tinderbox/jails/8.3-amd64/src.
*** Error code 1

Stop in /usr/local/portstools/tinderbox/jails/8.3-amd64/src.
*** Error code 1

Stop.
make: stopped in /usr/local/portstools/tinderbox/jails/8.3-amd64/src
</pre>
Cannot bootstrap C++.

Fix C++
-------

The meaning of the error should be clear to experienced FreeBSD admins.
FreeBSD 10 introduces a new C++11 capable C++ stack and the legacy
jails required the old stack to bootstrap the build process.

The solution was to add a line to `/etc/src.conf`:

~~~ make
WITH_GNUCXX=1
~~~
Bulild the legacy GNU toolchain on the FreeBSD 10 host.


And updating world:

~~~
cd /usr/src
# make -DNO_CLEAN buildworld
...
--------------------------------------------------------------
>>> World build completed on Wed Oct 30 10:28:06 CET 2013
--------------------------------------------------------------
# make installworld
…
~~~
Build and install world.

That didn't take long, because instead of rebuilding the entire world,
only the missing parts were added to the build due to the `NO_CLEAN`
flag.

Note, the `tc_command.sh` hack should stay in place to ensure make
compatibility. Unfortunately that seriously slows down the `makeJail`,
because it prevents parallel make. A workaround that does not require
meddling with the bootstrapping process would be to update several
jails at the same time.

So once again it was time to kick off the builds:

<pre>
# cd /usr/local/tinderbox/jails
# apply 'tc makeJail -j' *
8.3-amd64: updating jail with SVN
8.3-amd64: cleaning out /usr/local/portstools/tinderbox/jails/8.3-amd64/obj
8.3-amd64: cleaning out /usr/local/portstools/tinderbox/jails/8.3-amd64/tmp
8.3-amd64: making world
<span class="bad">ERROR: world failed - see /usr/local/portstools/tinderbox/jails/8.3-amd64/world.tmp</span>
Cleaning up after Jail creation.  Please be patient.
8.3-i386: updating jail with SVN
8.3-i386: cleaning out /usr/local/portstools/tinderbox/jails/8.3-i386/obj
8.3-i386: cleaning out /usr/local/portstools/tinderbox/jails/8.3-i386/tmp
8.3-i386: making world
<span class="bad">ERROR: world failed - see /usr/local/portstools/tinderbox/jails/8.3-i386/world.tmp</span>
Cleaning up after Jail creation.  Please be patient.
…
</pre>
More failures.

Fix `cc != gcc`
---------------

So basically the builds got a lot further, but still didn't complete.
It was time to look at `8.3-amd64/world.tmp` again:

<pre>
…
cc -O2 -pipe -DIN_GCC -DHAVE_CONFIG_H -DPREFIX=\"/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/usr\" -I/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../cc_tools -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../cc_tools -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/config -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcclibs/include -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcclibs/libcpp/include -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcclibs/libdecnumber   -I/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/legacy/usr/include -c /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/timevar.c
cc -O2 -pipe -DIN_GCC -DHAVE_CONFIG_H -DPREFIX=\"/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/usr\" -I/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../cc_tools -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../cc_tools -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/config -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcclibs/include -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcclibs/libcpp/include -I/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcclibs/libdecnumber   -I/usr/local/portstools/tinderbox/jails/8.3-amd64/obj/usr/local/portstools/tinderbox/jails/8.3-amd64/src/tmp/legacy/usr/include -DTARGET_NAME=\"amd64-undermydesk-freebsd\" -c /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/toplev.c
In file included from /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/toplev.c:58:
/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/output.h:123:6: warning: 'format' attribute argument not supported: __asm_fprintf__ [-Wignored-attributes]
     ATTRIBUTE_ASM_FPRINTF(2, 3);
     ^
/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/output.h:113:53: note: expanded from macro 'ATTRIBUTE_ASM_FPRINTF'
#define ATTRIBUTE_ASM_FPRINTF(m, n) __attribute__ ((__format__ (__asm_fprintf__, m, n))) ATTRIBUTE_NONNULL(m)
                                                    ^
/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/toplev.c:542:1: error: redefinition of a 'extern inline' function 'floor_log2' is not supported in C99 mode
floor_log2 (unsigned HOST_WIDE_INT x)
^
/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/toplev.h:174:1: note: previous definition is here
floor_log2 (unsigned HOST_WIDE_INT x)
^
/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/toplev.c:577:1: <span class="bad">error: redefinition of a 'extern inline' function 'exact_log2' is not supported in C99 mode</span>
exact_log2 (unsigned HOST_WIDE_INT x)
^
/usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int/../../../../contrib/gcc/toplev.h:180:1: note: previous definition is here
exact_log2 (unsigned HOST_WIDE_INT x)
^
1 warning and 2 errors generated.
*** Error code 1

Stop in /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc/cc_int.
*** Error code 1

Stop in /usr/local/portstools/tinderbox/jails/8.3-amd64/src/gnu/usr.bin/cc.
*** Error code 1

Stop in /usr/local/portstools/tinderbox/jails/8.3-amd64/src.
*** Error code 1

Stop in /usr/local/portstools/tinderbox/jails/8.3-amd64/src.
*** Error code 1

Stop.
make: stopped in /usr/local/portstools/tinderbox/jails/8.3-amd64/src
</pre>
More legacy issues.

In retrospect the cause is obvious, pre-10 releases of FreeBSD expect
`cc` to be `gcc`. So it was time to update the `/etc/src.conf` again:

~~~ make
WITH_GCC=1
WITH_GNUCXX=1
~~~

Make the legacy compiler the default.

And of course to update `world` like before.

So it was time for another try building a jail using `gcc`. To save
time I opened multiple terminals (I use `tmux`) and built one jail
in each:

<pre>
# /usr/local/tinderbox/jails
# env CC=gcc CXX=g++ apply 'tc makeJail -j' 8.3-amd64
TODO: Insert output
</pre>
