---
title: "powerd++: Even Better After EuroBSDcon"
journal: 1
tags:
- FreeBSD
- power-management
---

[slides]: {% post_url 2016-09-26-eurobsdcon-slides-released %}
[loadrec]: {% post_url 2016-09-05-reproducing-loads-for-eurobsdcon %}
[commit]: https://github.com/lonkamikaze/powerdxx/commit/493302644c87b740646be9105f876780ee54f1d6
To create [my slides for EuroBSDcon 2016][slides], I produced a number
of graphs to illustrate the positive effects of using a low pass
filter to mitigate the noise problem `powerd` is so suceptible to.
[Load recording][loadrec] and replay were the critical tools I developed
to show this. A side effect of being able to perform load replays
was the ability to create and test arbitrary loads.

Ringing
-------

One such test I devised, was a simple linear growth in load over
time. This test revealed an effect that I was aware of, but underestimated,
because the utility of filtering the load overshadowed its negative
impact. The following plots are based on completely noise free data,
so the effect is clearly visible:

![powerd++ 0.1.x load/freq plot](/plots/rampup-powerd++-0.1.x-hadp.svg "powerd++ 0.1.x load/freq plot")

The plots show load and clock frequency over time. The `load (abs)`
plot shows the absolute load, the `load (rel)` plot the load in relation
to the current clock frequency. The latter is what `powerd++` measures.
And you can see that the output signal, the `clock freq` plot, is
ringing.

`powerd++` overshoots its load target and actually takes the clock
frequency down for two notches, while the real (absolute) load is
still rising.

What is happening here is that the low pass filtering creates a feedback
with the sampled load. E.g. a sampled load of 0.8 at 800 MHz and 0.4
at 1600 MHz would be combined into a load of 0.6, ignoring  that 0.8
at 800 MHz are just 0.4 at 1600 MHz. So a stable load gets rated as
a load increment.

An Absolute Measure of Load
---------------------------

There is a simple solution to this issue — changing the way load is
measured from a relative to an absolute scale. If you look at the
above plot you might notice, that a unit for such a scale is readily
available to us, the MHz scale on the right.

Take the relative load, multiply it with the current clock frequency
and it results in the absolute load — [just in the unit MHz][commit]
instead of a fraction.

That means the 0.2.0 release of `powerd++` will measure load as million
CPU cycles consumed per second. The following plot shows, it has the
desired effect:

![powerd++ 0.2.0 load/freq plot](/plots/rampup-powerd++-0.2.0-hadp.svg "powerd++ 0.2.0 load/freq plot")

The ringing has completely been eliminated.

Another change that slipped in with the same commit is that the load
sample buffer is initialised with the target load, so the algorithm
has some bias to stay at the original frequency, when `powerd++`
starts.

Resources
---------

- [`powerd++ 0.2.0`](https://github.com/lonkamikaze/powerdxx/releases/tag/0.2.0)
- [`rampup-powerd++-0.1.x-hadp.csv`](/data/rampup-powerd++-0.1.x-hadp.csv)
- [`rampup-powerd++-0.2.0-hadp.csv`](/data/rampup-powerd++-0.2.0-hadp.csv)
