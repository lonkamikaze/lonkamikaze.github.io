---
title: "powerd++: Better CPU Clock Control for FreeBSD"
journal: 1
tags:
- FreeBSD
- power-management
---

{% include man.md p="powerd" s=8 %}
{% include man.md p="sysctl" s=3 %}
{% include man.md p="cpufreq" s=4 %}
Setting of P-States (power states a.k.a. steppings) on FreeBSD is
managed by [powerd(8)]. It has been with us since 2005, a time when
the Pentium-M single-core architecture was the cutting edge choice
for notebooks and dual-core just made its way to the desktop.

That is not to say that multi-core architectures were not considered
when `powerd` was designed, but as the number of cores grows and hyper-threading
has made its way onto notebook CPUs, `powerd` falls short.

Incentive
---------

> Don't you know it? You sit at your desk, reading technical documentation,
> occasionally scrolling or clicking on the next page link. The only
> (interactive) programs running are your web browser, an e-mail client
> and a couple of terminals waiting for input. There is a constant fan
> noise, which occasionally picks up for no apparent reason, making
> it a million times more annoying.
>
> You can't work like this!
>
> You start looking at the load, which is low but not minuscule. In
> the age of IMAP and node.js web browsers and e-mail clients are always
> a little busy. Still this is not enough to explain the fan noise.
>
> You're running `powerd` to reduce your energy footprint (for various
> reasons), or are you? Yes you are. So you start monitoring `dev.cpu.0.freq`
> and it turns out your CPU clock is stuck at maximum like the speedometer
> of an adrenaline junkie with a death wish.
>
> Something is wrong, your 15% to 30% load are way below the 50% default
> clock down threshold of `powerd`. You start digging, thinking you
> can tune `powerd` to do the right thing. Turns out you can't.

An Introduction to `powerd`
---------------------------

The following illustration shows `powerd`'s operation on a dual-CPU
system with two cores and hyper-threading each. That is not a realistic
system today, but it saves space in the illustration and contains
all the cases that need to be covered.


Note that …

- … the [sysctl(3)] interface flattens the architecture of the CPUs
  into a list of pipelines, each presented as individual CPUs.
- … `powerd` has the first CPU hard coded as the one controlling the
  clock frequency for all cores.
- … `powerd` uses the sum of all loads to control the clock frequency.

![powerd clock control](/illustrations/2016-04-07%20clock%20control%20legacy.svg
                        "Architecture of powerd.")

Powerd using the sum of all loads to rate the overall load of the
system allows single threaded loads to trigger higher P-States but
comes at the cost of triggering high P-States with low distributed
loads. The problem grows with the number of available cores. In the
illustrated systems a mean load of 12.5% results in a 100% load rating.
The same applies to a single quad-core CPU with hyper-threading.

Another problem resulting from this approach is that the optimal boundaries
for the hysteresis changes with the number of cores. Also, to protect
single core loads, `powerd` only permits boundaries from 0% to 100%.
This results in `powerd. changing into the highest P-State at the
drop of a needle and only clocking down if the load is close to 0.

The Design of `powerd++`
------------------------

The `powerd++` design has three significant differences. The way it
manages the CPUs/cores/threads presented through the sysctl interface,
the way that load is calculated and the way the target frequency is
determined.

During its initialisation phase `powerd++` assigns a frequency controlling
core to each core, grouping them by the core that offers the handle
to change the clock frequency. Unlike shown in the following illustration,
all cores will always be controlled by `dev.cpu.0`, because the [cpufreq(4)]
driver only supports global P-State changes. But `powerd++` is built
unaware of this limitation and will perform fine grained control the
moment the driver offers it.

To rate the load within a core group, each core determines its own
load and then passes it to the controlling core. The controlling core
uses the maximum of the loads in the group as the group load. This
approach allows single threaded applications to cause high load ratings
(i.e. up to 100%), but having small loads on all cores in a group
still results in a small load rating. Another advantage of this design
is that load ratings always stay within the 0% to 100% range. Thus
the same settings (including the defaults) work equally well for any
number of cores.

Instead of using a hysteresis to decide whether the clock frequency
should be increased, lowered or stay the same, `powerd++` uses a target
load to determine the frequency at which the current load would have
rated as the target load. This approach results in quick frequency
changes in either direction. E.g. given a target of 50% and a current
load of 100% the new clock frequency would be twice the current frequency.
To reduce sensitivity to signal noise more than two samples (5 by
default) can be collected. This works as a low pass filter but is
less damaging to the responsiveness of the system than increasing
the polling interval.

![powerd clock control](/illustrations/2016-04-07%20clock%20control.svg
                        "Architecture of powerd++.")

Resources
---------

The [code](https://github.com/lonkamikaze/powerdxx) is on github.
A FreeBSD port is available as
[sysutils/powerdxx](https://www.freshports.org/sysutils/powerdxx).

Afterthoughts
-------------

My experience in automotive and race car engineering came in handy.
If your noise filter is not in `O(1)` (per frame), you're doing it
wrong. If you have one control for many inputs a maximum or minimum
are usually the right choice, the sum barely is. E.g. if you have 3
sensors that report 62°C, 74°C and 96°C, you want to adjust your coolant
throughput to 96°C, not 232°C.

I hope that `powerd++` will be widely used (within the community)
and inspire the maintainers of [cpufreq(4)] to add support for per-CPU
frequency controls.

TODOs
-----

Currently the power source detection depends on ACPI, I need to implement
something similar for older and non-x86/amd64 systems. Currently those
just fall back to the *unknown* state.
