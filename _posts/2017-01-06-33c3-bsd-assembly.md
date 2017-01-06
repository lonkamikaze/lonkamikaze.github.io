---
title: 33C3 BSD Assembly
news:  1
tags:
- CCC
- BSD
- FreeBSD
---

[33C3]:           https://events.ccc.de/congress/2016/wiki/
[H²]:             https://twitter.com/__h2__
[H² tweet]:       https://twitter.com/__h2__/status/781925735565037568
[erdgeist]:       https://twitter.com/erdgeist
[erdgeist tweet]: https://twitter.com/erdgeist/status/800849293791764481
[erdgeist talk]:  https://media.ccc.de/v/33c3-8388-kampf_dem_abmahnunwesen
[BSD assembly]:   https://events.ccc.de/congress/2016/wiki/Assembly:BSD
[CCC]:            https://ccc.de/
[sign]:           https://www.flickr.com/photos/145887287@N06/31102644143/in/album-72157676759711742/
[weird bug]:      https://github.com/lonkamikaze/powerdxx/issues/3
{% include man.md p="pthread" s=3 %}
The idea of having a [BSD assembly] at the [33C3] had been spreading
through the community for a while. Things got real when [H²] shouted
out to a couple of people [via twitter][H² tweet].
The elusive [erdgeist] was first to [register the assembly][erdgeist tweet].
Ironically the only time I talked to him was [after his talk][erdgeist talk].
I don't think he ever showed up at the assembly.

![BSD assembly table](https://c3.staticflickr.com/6/5765/31764131762_2632bafac2_b.jpg)

In terms of attendance the assembly was an outstanding success.
Especially on the first day our table filled up and we had to start
borrowing chairs from other tables, while our direct neighbour assembly,
had at most two people in attendance.

This assembly was a counter reaction to the dwindling BSD presence
at [CCC] events. As such this was mostly a get-to-know for interested
parties. Apart from the obligatory RUN BSD stickers we didn't have
any visual clues and were notoriously difficult to find. The map
feature of the wiki was broken throughout congress (according to
unconfirmed rumours it worked in Safari), so we put instructions
for finding us into the wiki and improvised a little with the [sign].
The next time we will be prepared a little better.

Throughout congress we mostly ran BSD support for visitors. Some
fixes were committed to OpenBSD Wifi (mail a link to the commit please!).
I got a lot of support in debugging this [weird bug].

powerd++ Bug
------------

The bug only occurs on FreeBSD 12-CURRENT and as far as we could tell
with truss and dtrace, signals sent to a process compiled with a
C++ compiler get lost. This affects custom signal handlers like in
the `powerd++` binary as well as well as the default signal handlers
used by the `loadrec` binary. The bug shows itself by the processes
not terminating upon reception of `SIGHUP`, `SIGINT` and `SIGTERM`.

According to `dtrace` signals sent via `kill` or `CTRL+C` are sent
to the process, but the signal handlers never get called.

That is, unless [`pthread(3)`] is linked into the binary. My assumption
is that `pthread` substitutes a lot of system functions with thread
safe versions and one of those fixes the problem.
