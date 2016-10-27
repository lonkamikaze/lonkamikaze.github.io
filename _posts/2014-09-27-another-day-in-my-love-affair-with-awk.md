---
title: Another day in my love affair with AWK
update: 2016-07-18
journal: 1
tags:
- AWK
- FreeBSD
- GNU
---
I consider myself a C/C++ developer. Right now I am embracing C++11
(I wanted to wait till it is actually well supported by compilers)
and I am loving it.

[awk-text-processing-speed]: {% post_url 2013-10-12-awk-text-processing-speed %}

<div class="note">
	<h4>Note</h4>
	<p>
		This article was updated {{ page.update }} to fix
		some typos and broken references.
	</p>
</div>

Despite my happy relationship with C/C++ I have maintained a torrid
affair with AWK for many years, which has spilled into this blog before:

- [Almost a year ago][awk-text-processing-speed] I concluded that
  MAWK is *freakin' fast* and GNU AWK *freakin' fast as a snail*
- [The past summer]({% post_url 2014-07-03-awk-reloaded %})
  I stumbled over a bottleneck in the one-true-AWK, default for \*BSD
  and Mac OS-X

<style type="text/css" scoped>
.nawk {
    margin: 3pt;
    background-color: #89abcd;
    padding: 0pt;
    color: #000000;
    white-space: nowrap;
}
.nawk:before {content: "nawk: "}

.gawk {
    margin: 3pt;
    background-color: #cd89ab;
    padding: 0pt;
    color: #000000;
    white-space: nowrap;
}
.gawk:before {content: "gawk: "}

.mawk {
    margin: 3pt;
    background-color: #abcd89;
    padding: 0pt;
    color: #000000;
    white-space: nowrap;
}
.mawk:before {content: "mawk: "}
</style>

A Matter of Accountability
--------------------------

So far circumstances dictated that either the script or the input
data or both had to be kept confidential. In this post both will be
publicly available. The purpose of this post is to give people the
opportunity to perform their own tests.

The following is required to perform the test:

- [`dbc2c.awk` and `templates.dbc2c`](https://github.com/lonkamikaze/hsk-libs/tree/4d1a902/scripts)
- [`j1939_utf8.dbc`](http://hackage.haskell.org/package/ecu-0.0.8/src/src/j1939_utf8.dbc)

The `dbc2c.awk` script was already part of
[my first post][awk-text-processing-speed].
It parses Vector DBC (Database CAN) files, an industry standard for
describing a set of devices, messages and signals for the real time
bus CAN (one can argue it's soft real time, it depends). The script
does the following things:

- Parse data from 1 or more input files
- Store the data in arrays, use indexes as references to describe relationships
- Output the data
  - Traverse the data structure and store attributes of objects in an array
  - Read a template
  - Insert data into the template and print on stdout

### Test Environment

- The operating system:

  `FreeBSD AprilRyan.norad 10.1-BETA2 FreeBSD 10.1-BETA2 #0 r271856:
  Fri Sep 19 12:55:39 CEST 2014
  root@AprilRyan.norad:/usr/obj/S403/amd64/usr/src/sys/S403  amd64`
- The compiler:
  - `FreeBSD clang version 3.4.1 (tags/RELEASE_34/dot1-final 208032) 20140512`
  - Target: `x86_64-unknown-freebsd10.1`
  - Thread model: posix
- CPU: Core i7@2.4GHz (Haswell)
- NAWK version: awk version 20121220 (FreeBSD)
- MAWK version: mawk 1.3.4.20140914
- GNU AWK version: GNU Awk 4.1.1, API: 1.1

Tests
-----

With the recent changeset `4d1a902`, the script switched from using
array iteration (`for (index in array) { … }`) to creating a numbered
index for each object type and iterate through them in order of creation
to make sure data is output in the same order with every AWK implementation.
This makes it much easier to compare and validate outputs from different
flavours of AWK.

To reproduce the tests, run:

~~~ sh
time -l awk -f scripts/dbc2c.awk -vDATE=whenever j1939_utf8.dbc | sha256
~~~
Validate the output of your test run.

The checksum for the output should read:

	9f0a105ed06ecac710c20d863d6adefa9e1154e9d3a01c681547ce1bd30890df

Checksum of the non-diagnostic output.

Here are my runtime results [25 pt/s]:

<div class="nawk" style="width: 155.75pt">6.23 s</div>
<div class="nawk" style="width: 158.00pt">6.32 s</div>
<div class="nawk" style="width: 156.75pt">6.27 s</div>

<div class="gawk" style="width: 294.75pt">11.79 s</div>
<div class="gawk" style="width: 297.00pt">11.88 s</div>
<div class="gawk" style="width: 295.00pt">11.80 s</div>

<div class="mawk" style="width: 49.50pt">1.98 s</div>
<div class="mawk" style="width: 50.50pt">2.02 s</div>
<div class="mawk" style="width: 49.25pt">1.97 s</div>

Memory usage (maximum resident set size) [0.005 pt/k]:

<div class="nawk" style="width: 110.00pt">22000 k</div>
<div class="gawk" style="width: 253.44pt">50688 k</div>
<div class="mawk" style="width: 133.22pt">26644 k</div>

Conclusion
----------

Once again the usual order of things establishes itself. GNU AWK wastes
our time and memory while MAWK takes the winner's crown and NAWK sticks
to the middle ground.

The `dbc2c.awk` script [has been tested before][awk-text-processing-speed]
and GNU AWK actually performs much better this time, 6.0 instead of
9.6 times slower than MAWK. Maybe just parsing one file instead of
3 helps or the input data produces less collisions for the hashing
algorithm (AWK array indexes are always cast to string and stored
in hash tables).

In any way I'd love to see some more benchmarks out there. And maybe
someone bringing their favourite flavour of AWK to the table.
