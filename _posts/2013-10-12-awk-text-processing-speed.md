---
title: AWK Text Processing Speed
---

My default brand of AWK is the One-True-AWK also known as NAWK,
coming with FreeBSD. For portability I have started supporting GNU
AWK (henceforth GAWK). Because I work with people using Ubuntu, MAWK
also made it into my list recently.

The Wikipedia article has a
[list of AWK versions](https://en.wikipedia.org/wiki/Awk#Versions_and_implementations).

Tests
-----

### Test Environment

The tests are run on a Core2Duo throttled to 800MHz on FreeBSD 9 r254957
(adm64) using a 
[set of AWK scripts](https://github.com/lonkamikaze/hsk-libs/tree/master/scripts)
dealing with processing or generating C-code.

<style type="text/css">
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

### `cstrip.awk`

This script passes the given arguments to `cpp` and collects the
output in a single string, reformatting the resulting code to one
command per line with all obsolete spaces discarded. Its purpose
is to simplify going through the code using regular expressions in
other scripts. For the following measurements 31 files, a total of
279777 (273.2k) bytes of code, were passed to the script.


<div class="nawk" style="width: 11.1pt">1.11 s</div>
<div class="nawk" style="width: 11.1pt">1.11 s</div>
<div class="nawk" style="width: 11.3pt">1.13 s</div>

<div class="gawk" style="width: 12.3pt">1.23 s</div>
<div class="gawk" style="width: 12.3pt">1.23 s</div>
<div class="gawk" style="width: 12.0pt">1.20 s</div>

<div class="mawk" style="width: 26.7pt">2.67 s</div>
<div class="mawk" style="width: 27.0pt">2.70 s</div>
<div class="mawk" style="width: 26.5pt">2.75 s</div>

Memory usage (maximum resident set size):

<div class="nawk" style="width: 42.72pt">4272 k</div>
<div class="gawk" style="width: 46.20pt">4620 k</div>
<div class="mawk" style="width: 43.44pt">4344 k</div>

### `overlays.awk`, `sanity.awk`

The following two tests were supposed to refer to `overlays.awk` and
`sanity.awk`, which both call `cstrip.awk` and both exhibited no
significant runtime difference to just calling `cstrip.awk`.

### `dbc2c.awk`

This script parses Vector DBC (Database CAN) files. Every object
in the file is parsed and stored in arrays. All data and relations
are kept in memory, no information is discarded. Afterwards a set
of templates is used to output this information into a C-style header
file with doxygen documentation. The script is run on 3 CAN databases
totalling 674576 (658.8k) bytes of input and producing 2678866 (2.55m)
bytes of output.

<div class="nawk" style="width: 75.1pt">7.51 s</div>
<div class="nawk" style="width: 75.0pt">7.50 s</div>
<div class="nawk" style="width: 75.3pt">7.53 s</div>

<div class="gawk" style="width: 280.8pt">28.08 s</div>
<div class="gawk" style="width: 281.2pt">28.12 s</div>
<div class="gawk" style="width: 280.2pt">28.02 s</div>

<div class="mawk" style="width: 28.7pt">2.87 s</div>
<div class="mawk" style="width: 28.2pt">2.82 s</div>
<div class="mawk" style="width: 29.2pt">2.92 s</div>


Memory usage (maximum resident set size):

<div class="nawk" style="width: 119.08pt">11908 k</div>
<div class="gawk" style="width: 255.60pt">25560 k</div>
<div class="mawk" style="width: 105.68pt">10568 k</div>

### `xml.awk`

This script parses an XML file (to be exact the subset of XML that
is used by Keil µVision for its configuration files), offers a set
of arguments to manipulate and reprint the XML tree. The XML code
is not stored in memory, but recreated from the tree generated when
parsing the file.

In this test case 2 XML files, 48757 (47.6k) bytes are parsed and
simply printed.

<div class="nawk" style="width: 10.2pt">1.02 s</div>
<div class="nawk" style="width: 10.2pt">1.02 s</div>
<div class="nawk" style="width: 10.3pt">1.03 s</div>

<div class="gawk" style="width: 33.8pt">3.38 s</div>
<div class="gawk" style="width: 33.5pt">3.35 s</div>
<div class="gawk" style="width: 33.4pt">3.34 s</div>

<div class="mawk" style="width: 1.2pt">0.12 s</div>
<div class="mawk" style="width: 1.2pt">0.12 s</div>
<div class="mawk" style="width: 1.3pt">0.13 s</div>

Memory usage (maximum resident set size):

<div class="nawk" style="width: 33.92pt">3392 k</div>
<div class="gawk" style="width: 59.76pt">5976 k</div>
<div class="mawk" style="width: 27.24pt">2724 k</div>

Conclusions
-----------

From the similar runtime of NAWK and GAWK in the `cstrip.awk` test
case, I gather that the majority of the runtime is caused by `cpp`.
So the higher runtime of MAWK seems to result from bad performance
performing `gsub()` calls on entire file sized strings.

The MAWK performance in the `dbc2c.awk` test case on the other hand
is extremely remarkable as well, outperforming GAWK by a factor of
~9.6, where NAWK only manages ~3.7. Clearly MAWK shines at array
handling.

MAWK recommends itself further in the XML parsing and printing case,
where it outperforms NAWK by a factor of ~7.8 and GAWK by a factor
of 25.7!

All in all I have to conclude that using GAWK, the default for many
GNU/Linux distributions, is a bad choice. It offers a couple of additional
features, but GAWK is simply too slow to benefit from them when processing
large amounts of data. NAWK outperforms GAWK in all my test cases.
And despite the lapse with the `cstrip.awk` test case, the performance
of MAWK is just plain astonishing.

Too bad MAWK is released under GPLv2, which doesn't recommend it
for distribution with FreeBSD (NAWK is released under an MIT-style
license). It might be a valuable effort to look at the hashing functions
of NAWK to improve its array performance.

### A Note on MAWK

MAWK is a little more picky than other flavours of AWK. First, no
variable, no matter the context, may have the same name as a function.

The second difference to NAWK or GAWK is that MAWK does not support
`length(array)`, `length()` can only be applied to strings. In most
cases I only need to know whether an array has elements left at all.
In such cases a simple function like this can be used:

~~~ awk
function empty(array, i) {
	for (i in array) {
		return 0
	}
	return 1
}
~~~

Finally, MAWK uses exponential output for large numbers, even those
cast to `int` (AWK interpreters store all numbers in double precision
floating point format). In order to make sure that output is always
identical use `printf`/`sprintf("%f", number)` and `"%.f"` for integers.

Amendments
----------

### Versions

- `nawk` 20121220 (FreeBSD)
- `gawk` 4.1.0
- `mawk` 1.3.3


### `nextfile`

MAWK does not support `nextfile`. This can easily be worked around
and here is an update list of measurements for the `cstrip.awk` test
case:

<div class="nawk" style="width: 10.8pt">1.08 s</div>
<div class="nawk" style="width: 10.8pt">1.08 s</div>
<div class="nawk" style="width: 10.9pt">1.09 s</div>

<div class="gawk" style="width: 11.8pt">1.18 s</div>
<div class="gawk" style="width: 11.7pt">1.17 s</div>
<div class="gawk" style="width: 11.9pt">1.19 s</div>

<div class="mawk" style="width: 14.6pt">1.46 s</div>
<div class="mawk" style="width: 14.5pt">1.45 s</div>
<div class="mawk" style="width: 14.4pt">1.44 s</div>

Memory usage (maximum resident set size):

<div class="nawk" style="width: 44.56pt">4456 k</div>
<div class="gawk" style="width: 46.20pt">4680 k</div>
<div class="mawk" style="width: 44.44pt">4444 k</div>

