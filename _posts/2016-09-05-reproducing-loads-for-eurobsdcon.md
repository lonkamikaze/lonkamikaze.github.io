---
title: Reproducing Loads for EuroBSDcon
news: 1
tag:
- FreeBSD
- power-management
- talks
---

{% include man.md p="loadrec" s=1 %}
On Sunday the 25th of September I will talk about
[powerd++]({% post_url 2016-04-07-powerdxx-better-cpu-clock-control-for-freebsd %})
at the [EuroBSDcon 2016](https://2016.eurobsdcon.org/speakers/#dominicfandrey).
I have already provided plenty of materials about how and why I think
`powerd++` is better than `powerd`. But on the conference I want to
do the proper thing and provide reproducible measurements and metrics
to quantify what better actually means.

To that end I have just pushed a load recorder into
[the repository](https://github.com/lonkamikaze/powerdxx). It creates
a record of the relevant sysctls over a given time period. If you
want to play with it, fetch the repo, run `make` and make sure to
read the manual page:

~~~ sh
nroff -mdoc loadrec.1 | less -r
~~~
Open the [loadrec(1)] manual from the repository snapshot.

You can run it right out of the build directory.

Of course recording loads is only half of the business, the other
half is reproducing them. My personal deadline to get there is ten
days.
