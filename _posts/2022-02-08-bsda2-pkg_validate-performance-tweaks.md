---
title:   "bsda2: pkg_validate Performance Tweaks"
journal: 1
tags:
- shell-scripting
- programming
- BSDA2
- FreeBSD
---

[LST.sh]:         https://github.com/lonkamikaze/bsda2/blob/master/ref/lst.md
[bsda2]:          https://github.com/lonkamikaze/bsda2
[bsda2-snapshot]: https://github.com/lonkamikaze/bsda2/tree/4793233137585488905c22d77a216b1fc28e4421
I am currently updating the [bsda2] code for `pkg_validate` with
[LST.sh], this adds some overhead (however small) and to counter
that I decided to try tweak the performance a little.
Two approaches have shown benefits.

Tweaking Checksum Verification
------------------------------

Checksum verification is performed in two steps. The checksum binary
(currently only sha256 is supported) is passed a set of files that
it checks in one go. The resulting list is checked against the reference
checksums and mismatches are inspected individually in order to allow
providing a reason (e.g. file missing, insufficient privileges etc.).

One important case is symlinks, the checksum tool scans the files
referred to by a symlink whereas the reference checksum is a checksum
of the path referred to by the symlink. This has to be reproduced
(including reproducing a bug in pkg, which cannot be fixed without
altering checksums).

The performance tweak performed is substituting symlinks with `/dev/null`
in the file list in order to trigger the checksum mismatch without
actually scanning a file.
An alternative approach would be to substitute an invalid file name,
but it turns out that checksumming `/dev/null` is faster than failing
on a missing file.

The other tweak is changing the batch size, finding the correct batch
size is simply a logarithmic search with a performance metric. The
metric I used is the *validate all packages* benchmark.

A small batch size benefits improves CPU utilisation at the beginning
and end of the process

A larger batch size reduces overhead (less calls of the `sha256`
executable, more locking operations on the task queue).

The original batch size was 64, runtime improved till 1024, beyond
which it stalled and then degraded. So the new batch size is 1024.

Benchmark
---------

The test system is an Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz with
6 cores / 12 threads, running FreeBSD stable/13-n248234-3218666bd082.
The maximum turbo clock is 4.5 GHz for a single core and 4.0 GHz for
all cores. The CPU clock is controlled by the hwpstate driver, but
as far as I can tell single clock turbo does not work for this model,
hwpstate always sets the same clock speed for all cores.

<style type="text/css" scoped>
.v042 {
	margin: 3pt;
	background-color: #89abcd;
	padding: 0pt;
	white-space: nowrap;
}
.v042:before {content: "0.4.2: "}

.v04x {
	margin: 3pt;
	background-color: #cd89ab;
	padding: 0pt;
	white-space: nowrap;
}
.v04x:before {content: "current: "}
</style>

### pkg_validate (1207 packages)

This benchmark was performed seven times for each `pkg_validate` version:

```sh
for i in $(jot 7); do time pkg_validate; done
```
Benchmark validating all packages seven times in a row.

The first two runs show additional turbo boost benefits, whereas
the third run has reached thermal equilibrium and performance is fairly
stable from that point onwards. The median runtime of pkg_validate
0.4.2 is 51.42 s and the tweaked version 45.79 s. A 10.9 % runtime
reduction.

Usually a reduction in real time is achieved by improving the utilisation
of cores, but in this case we actually managed to reduce actual work
done (the *user + sys* measurements).

#### real [1 pt/s]

<div class="v042" style="width: 50.72pt">50.72 s</div>
<div class="v042" style="width: 50.49pt">50.49 s</div>
<div class="v042" style="width: 51.56pt">51.56 s</div>
<div class="v042" style="width: 51.42pt">51.42 s</div>
<div class="v042" style="width: 51.41pt">51.41 s</div>
<div class="v042" style="width: 51.51pt">51.51 s</div>
<div class="v042" style="width: 51.88pt">51.88 s</div>

<div class="v04x" style="width: 44.54pt">44.54 s</div>
<div class="v04x" style="width: 44.53pt">44.53 s</div>
<div class="v04x" style="width: 45.16pt">45.16 s</div>
<div class="v04x" style="width: 45.95pt">45.95 s</div>
<div class="v04x" style="width: 45.85pt">45.85 s</div>
<div class="v04x" style="width: 45.79pt">45.79 s</div>
<div class="v04x" style="width: 45.86pt">45.86 s</div>

#### user + sys [1 pt/s]

<div class="v042" style="width: calc((213.02 + 123.78) * 1pt)">213.02 user + 123.78 sys</div>
<div class="v042" style="width: calc((218.13 + 121.85) * 1pt)">218.13 user + 121.85 sys</div>
<div class="v042" style="width: calc((217.33 + 124.52) * 1pt)">217.33 user + 124.52 sys</div>
<div class="v042" style="width: calc((223.38 + 124.96) * 1pt)">223.38 user + 124.96 sys</div>
<div class="v042" style="width: calc((226.02 + 124.19) * 1pt)">226.02 user + 124.19 sys</div>
<div class="v042" style="width: calc((222.61 + 124.68) * 1pt)">222.61 user + 124.68 sys</div>
<div class="v042" style="width: calc((224.00 + 125.48) * 1pt)">224.00 user + 125.48 sys</div>

<div class="v04x" style="width: calc((169.65 + 111.38) * 1pt)">169.65 user + 111.38 sys</div>
<div class="v04x" style="width: calc((175.92 + 111.01) * 1pt)">175.92 user + 111.01 sys</div>
<div class="v04x" style="width: calc((174.80 + 114.71) * 1pt)">174.80 user + 114.71 sys</div>
<div class="v04x" style="width: calc((184.08 + 115.90) * 1pt)">184.08 user + 115.90 sys</div>
<div class="v04x" style="width: calc((180.01 + 115.21) * 1pt)">180.01 user + 115.21 sys</div>
<div class="v04x" style="width: calc((181.42 + 116.32) * 1pt)">181.42 user + 116.32 sys</div>
<div class="v04x" style="width: calc((184.42 + 116.43) * 1pt)">184.42 user + 116.43 sys</div>

### pkg_validate texlive-\*

To verify that there are no regressions I also ran a smaller test
case validating the texlive packages:

```sh
for i in $(jot 9); do time pkg_validate texlive-\*; done
```
Benchmark validating all texlive packages nine times in a row.

This benchmark is dominated by the texlive-texmf package, which contributes
85605 out of 117570 files (72.8 %). This is the reason why the simple
one job per package approach does not scale well.

Luckily even this use case gets away with a net win, where I expected
at least a small performance regression from the tweaks.

It is noteworthy that this benchmarks does not seem to be thermally
limited, increasing the number of runs to 25 did not make a difference
either. Monitoring the system during the runs implies that CPU
utilisation is too low to reach a state where thermal throttling
limits the turbo boost.

It might mean there is some untapped performance potential - or we
are constrained by the limits of file system IO.

#### real [5 pt/s]

<div class="v042" style="width: calc(10.69 * 5pt)">10.69 s</div>
<div class="v042" style="width: calc(10.61 * 5pt)">10.61 s</div>
<div class="v042" style="width: calc(10.45 * 5pt)">10.45 s</div>
<div class="v042" style="width: calc(10.35 * 5pt)">10.35 s</div>
<div class="v042" style="width: calc(10.54 * 5pt)">10.54 s</div>
<div class="v042" style="width: calc(10.60 * 5pt)">10.60 s</div>
<div class="v042" style="width: calc(10.47 * 5pt)">10.47 s</div>
<div class="v042" style="width: calc(10.42 * 5pt)">10.42 s</div>
<div class="v042" style="width: calc(10.82 * 5pt)">10.82 s</div>

<div class="v04x" style="width: calc(9.45 * 5pt)">9.45 s</div>
<div class="v04x" style="width: calc(9.42 * 5pt)">9.42 s</div>
<div class="v04x" style="width: calc(9.50 * 5pt)">9.50 s</div>
<div class="v04x" style="width: calc(9.38 * 5pt)">9.38 s</div>
<div class="v04x" style="width: calc(9.54 * 5pt)">9.54 s</div>
<div class="v04x" style="width: calc(9.37 * 5pt)">9.37 s</div>
<div class="v04x" style="width: calc(9.45 * 5pt)">9.45 s</div>
<div class="v04x" style="width: calc(9.36 * 5pt)">9.36 s</div>
<div class="v04x" style="width: calc(9.48 * 5pt)">9.48 s</div>

#### user + sys [5 pt/s]

<div class="v042" style="width: calc((22.92 + 15.94) * 5pt)">22.92 user + 15.94 sys</div>
<div class="v042" style="width: calc((23.56 + 14.65) * 5pt)">23.56 user + 14.65 sys</div>
<div class="v042" style="width: calc((22.83 + 15.08) * 5pt)">22.83 user + 15.08 sys</div>
<div class="v042" style="width: calc((23.18 + 14.58) * 5pt)">23.18 user + 14.58 sys</div>
<div class="v042" style="width: calc((22.82 + 15.33) * 5pt)">22.82 user + 15.33 sys</div>
<div class="v042" style="width: calc((22.77 + 16.04) * 5pt)">22.77 user + 16.04 sys</div>
<div class="v042" style="width: calc((22.92 + 14.90) * 5pt)">22.92 user + 14.90 sys</div>
<div class="v042" style="width: calc((22.97 + 14.89) * 5pt)">22.97 user + 14.89 sys</div>
<div class="v042" style="width: calc((22.81 + 15.70) * 5pt)">22.81 user + 15.70 sys</div>

<div class="v04x" style="width: calc((20.11 + 12.32) * 5pt)">20.11 user + 12.32 sys</div>
<div class="v04x" style="width: calc((19.97 + 12.25) * 5pt)">19.97 user + 12.25 sys</div>
<div class="v04x" style="width: calc((19.28 + 12.37) * 5pt)">19.28 user + 12.37 sys</div>
<div class="v04x" style="width: calc((18.90 + 11.83) * 5pt)">18.90 user + 11.83 sys</div>
<div class="v04x" style="width: calc((20.01 + 11.83) * 5pt)">20.01 user + 11.83 sys</div>
<div class="v04x" style="width: calc((19.64 + 11.80) * 5pt)">19.64 user + 11.80 sys</div>
<div class="v04x" style="width: calc((19.44 + 12.27) * 5pt)">19.44 user + 12.27 sys</div>
<div class="v04x" style="width: calc((19.50 + 11.62) * 5pt)">19.50 user + 11.62 sys</div>
<div class="v04x" style="width: calc((19.62 + 11.98) * 5pt)">19.62 user + 11.98 sys</div>

Conclusion
----------

It's always pleasant to find some low hanging fruit. If you want
to play with the batch size yourself, you will be able to using the
[latest commit][bsda2-snapshot]:

```
$ for i in $(jot 14 0); do time src/pkg_validate -b$((1 << i)) texlive-\* || break; done
       54.06 real       183.56 user       444.20 sys
       30.73 real       114.92 user       239.29 sys
       18.74 real        72.86 user       123.50 sys
       14.27 real        49.49 user        60.66 sys
       12.19 real        36.52 user        38.02 sys
       11.35 real        31.05 user        25.05 sys
       10.69 real        26.42 user        18.47 sys
       10.20 real        23.14 user        15.78 sys
        9.75 real        22.41 user        13.26 sys
        9.64 real        20.63 user        12.17 sys
        9.40 real        18.70 user        12.06 sys
        9.22 real        18.02 user        11.95 sys
        9.17 real        17.70 user        11.26 sys
        9.22 real        17.00 user        11.52 sys
```
Verify texlive packages with batch sizes from 1 to 8192.

References
----------

* [LST.sh docs on GitHub][LST.sh]
* [bsda2 on GitHub][bsda2]
* [bsda2 on GitHub (2022-02-08)][bsda2-snapshot]
