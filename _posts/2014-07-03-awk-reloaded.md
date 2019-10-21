---
title: AWK Reloaded
journal: 1
tags:
- AWK
- FreeBSD
- GNU
---
Last year I
[compared the performance of 3 AWK interpreters]({% post_url 2013-10-12-awk-text-processing-speed %}),
NAWK, GAWK and MAWK. For the test I used 3 of my `.awk` scripts (available
under Beerware). But the data I processed with them was confidential.
 Any way, NAWK won 1/3, MAWK 2/3 (with astonishing leads), GAWK was
the clear looser with abysmal performance in 2/3 tests.

Recently I developed a run time interpreter for the
[Heidenhain NC](http://content.heidenhain.de/doku/tnc_guide/html/index.html)
(Numerical Control) language. The code of the script as well as the
program it interprets are confidential, unfortunately. But the results
are interesting nonetheless.

<style type="text/css" scoped>
.nawk {
    margin: 3pt;
    background-color: #89abcd;
    padding: 0pt;
    white-space: nowrap;
}
.nawk:before {content: "nawk: "}

.gawk {
    margin: 3pt;
    background-color: #cd89ab;
    padding: 0pt;
    white-space: nowrap;
}
.gawk:before {content: "gawk: "}

.mawk {
    margin: 3pt;
    background-color: #abcd89;
    padding: 0pt;
    white-space: nowrap;
}
.mawk:before {content: "mawk: "}
</style>

Tests
-----

### Test Environment

Unfortunately I cannot run the tests on the same machine as last time,
it was stolen during a visit in the UK last winter.

So this time the tests are run on its replacement, an Intel Haswell
Core i-7 (2 cores, 4 pipelines) at 2.4 GHz under FreeBSD 10 r267867 (amd64).

### AWK Versions

- nawk 20121220 (FreeBSD)
- gawk 4.1.1
- mawk 1.3.4

### `hhrti.awk` [1 pt/s]

This is a test run with the aforementioned run time interpreter.
There is a more [in depth explanation](#the-heidenhain-real-time-interpreter)
at the end of this article.

<div class="nawk" style="width: 150.43pt">150.43 s</div>
<div class="nawk" style="width: 149.41pt">149.41 s</div>
<div class="nawk" style="width: 149.29pt">149.29 s</div>

<div class="gawk" style="width: 67.40pt">67.40 s</div>
<div class="gawk" style="width: 67.86pt">67.86 s</div>
<div class="gawk" style="width: 67.61pt">67.61 s</div>

<div class="mawk" style="width: 48.97pt">48.97 s</div>
<div class="mawk" style="width: 47.48pt">47.48 s</div>
<div class="mawk" style="width: 48.02pt">48.02 s</div>

Memory usage (maximum resident set size):

<div class="nawk" style="width: 28.64pt">2864 k</div>
<div class="gawk" style="width: 42.40pt">4240 k</div>
<div class="mawk" style="width: 27.60pt">2760 k</div>

### `xml.awk` [100 pt/s]

This is one of the tests run last time, to confirm that the interpreters
still compare similarly with the previous scripts, despite the updated
test platform. That seems to be the case here.

<div class="nawk" style="width: 16pt">0.16 s</div>
<div class="nawk" style="width: 16pt">0.16 s</div>
<div class="nawk" style="width: 16pt">0.16 s</div>

<div class="gawk" style="width: 57pt">0.57 s</div>
<div class="gawk" style="width: 57pt">0.57 s</div>
<div class="gawk" style="width: 58pt">0.58 s</div>

<div class="mawk" style="width: 2pt">0.02 s</div>
<div class="mawk" style="width: 2pt">0.02 s</div>
<div class="mawk" style="width: 2pt">0.02 s</div>

Conclusions
-----------

Consistently with the previous performance tests, MAWK takes the lead.
What is surprising that GAWK performs well with only 1.38 times the
run time of MAWK, which is a far cry from the abysmal performance
it exhibited in some of the other tests. A quick rerun of the previous
tests shows the same performance gaps as before, so neither the slight
version changes nor the new compiler version (clang 3.4.1) introduced
a performance boost in GAWK.

The real surprise is the performance of NAWK. This is the first test
case where it performs worse than GAWK, with a runtime factor of 3.0.
That's a far cry from GAWK's sad >25 in the `xml.awk` case, but still
it hints to a bottleneck in NAWK.

### Differences to Previous Tests

This test is a lot less array heavy than the `dbc2c.awk` and `xml.awk`
test cases. The parsing stage barely takes any time after that only
small local arrays are used for temporary tokenizing. The most time
consuming operation seems to be evaluating arithmetic, because whenever
an operation is performed it creates a number of copy operations.
Depending on the operator all following tokens need to be shifted
one or two places.

Bottleneck Test
---------------

In order to verify the assumption that copies in arrays might be responsible
I created a small script that performs this operation repeatedly:

~~~ perl
BEGIN {
	TXT = "111 222 333 444 555 666 777 888 999 000"
	REPEAT = 100000
	if (ARGC > 1) {
		REPEAT = ARGV[--ARGC]
		delete ARGV[ARGC]
	}
	srand() # Seed

	# Perform the test this many times
	for (i = 1; i <= REPEAT; i++) {
		# Create an array with tokens
		len = split(TXT, a)
		a[0] = len # Store the length in index 0, this is very
		           # convenient in real apps with lots of arrays

		# Test case, delete a random field until none
		# are left
		while (a[0]) {
			# Select a random entry to delete
			del = int(rand() * 65536) % a[0] + 1

			# Shift the following tokens left
			for (p = del; p < a[0]; p++) {
				a[p] = a[p + 1]
			}
			# Delete the tail
			delete a[a[0]--]
		}
	}
}
~~~
`bottleneck.awk`, reproduces the observed performance issue of NAWK.

### `bottleneck.awk` [10 pt/s]

This *artificial* test seems to confirm this, by reproducing the same
performance pattern and amplifying the performance problem of NAWK.
The script was run with 200000 repetitions.

<div class="nawk" style="width: 122.4pt">12.24 s</div>
<div class="nawk" style="width: 122.8pt">12.28 s</div>
<div class="nawk" style="width: 121.7pt">12.17 s</div>

<div class="gawk" style="width: 22.9pt">2.29 s</div>
<div class="gawk" style="width: 22.9pt">2.29 s</div>
<div class="gawk" style="width: 22.8pt">2.28 s</div>

<div class="mawk" style="width: 16.8pt">1.68 s</div>
<div class="mawk" style="width: 16.3pt">1.63 s</div>
<div class="mawk" style="width: 16.9pt">1.69 s</div>

Memory usage (maximum resident set size):

<div class="nawk" style="width: 24.88pt">2488 k</div>
<div class="gawk" style="width: 35.96pt">3596 k</div>
<div class="mawk" style="width: 24.76pt">2476 k</div>

---

The Heidenhain Real Time Interpreter
------------------------------------

The Heidenhain NC language can be used to control an NC mill. I.e.
access various functions of the machine, such as cooling systems,
automatic tool changers and provide milling instructions. Additionally
it has programming instructions that can be used to make on the fly
calculations and decisions. The purpose of the interpreter is to perform
arithmetic and conditional flow in advance.

The need for this arose with a program written for a research project,
which is so computation heavy that it causes the machine to stutter.

The interpreter works in two stages, a code parsing stage and an evaluation
stage.

### Parsing

In this stage every command is stored in a one-way linked list. Additional
code files may be called within a program, those are parsed after
the current file has been completed and appended to the same list.

The Heidenhain NC language has several kinds of commands, most of
these are pretty static, they access machine functions, or describe
target coordinates or curves. These kinds of commands are what the
interpreter *outputs* in the evaluation stage.

The other kind of commands provide arithmetic and program flow:

- Variable assignments
- Arithmetic expressions (really part of variable assignments)
- Labels
- Label calls
- Conditional label calls (i.e. IF)
- Program calls

The list is not complete, but it should get the idea across.

Every list entry is classified during parsing stage, and some are
preprocessed. E.g. labels and subprogram entries are recorded in an
associative array so they can be branched to in the evaluation stage.

### Evaluation

In this stage the *interpretation* is performed. The program starts
with an empty call stack at the first parsed code line. Each line
is evaluated according to its classification.

- Variable assignments are evaluated and stored in an associative array containing name, value pairs
- Label calls are performed
- Conditions are evaluated and either branch to a label, that is fetched
  from the array recorded during parsing, or continue with the next
  line
- Calls to other programs cause a reference to the current code line
  to be pushed on the stack
- Ends of programs cause a call back to the code line recorded on
  the stack, if the stack is empty the interpreter terminates
- …

Every command that is not classified for special treatment receives
the following default treatment:

1. Substitute variables with their current values
2. Output the command

The result is a flat NC program that does no longer contain arithmetic and conditional code. E.g:

~~~ conf
0    BEGIN PGM mandelbrot_kante MM
1    BLK FORM 0.1 Z X+0 Y-90.0000 Z-50
2    BLK FORM 0.2 X+220.0000 Y+90.0000 Z+0
3    TOOL CALL 4 Z S32000 F8000
4    M3
5    L Z+20 FMAX
6    L X+110.0000 Y-52.2387 FMAX
7    L Z+2 FMAX
8    L Z-0.5000 F800
9    L X+110.2000 Y-52.2387 F8000
[…]
7758 L X+109.4000 Y-52.8387 F8000
7759 L X+109.4000 Y-52.6387 F8000
7760 L X+109.4000 Y-52.4387 F8000
7761 L X+109.4000 Y-52.2387 F8000
7762 L X+109.6000 Y-52.2387 F8000
7763 L X+109.8000 Y-52.2387 F8000
7764 L X+110.0000 Y-52.2387 F8000
7765 L X+110.2000 Y-52.2387 F8000
7766 L Z+50 FMAX
7767 END PGM mandelbrot_kante MM
~~~
Flattened Heidenhain NC code.
