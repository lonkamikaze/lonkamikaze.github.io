---
title: Project Docs Rollout
news:  1
tag:
- meta
---

[`powerd++`]: {{ site.profile }}/powerdxx
[`hsk-libs`]: {{ site.profile }}/hsk-libs
[Doxygen]:    http://doxygen.nl/
[High Speed Karlsruhe]: http://highspeed-karlsruhe.de
I have started rolling out project documentation on GitHub Pages.
This far for the [`powerd++`] and the [`hsk-libs`] project. The documentation
is generated using [Doxygen]. For the time being I am not currently
planning on covering more projects, at least until I make a significant
release.

In the process of making that happen I created `gh-pages` orphan
branches in the respective projects, pushed them to GitHub and imported
them into `master` as a submodule. Then I fixed up the Makefiles
to build the documentation and put it into the submodule path, so
that I only have to do `add`, `commit` and `push` inside the submodule
to publish. I didn't want to automate this last step, I want to be
able to `git diff` before I go ahead.

[commit:hsk-libs/Makefile]: {{ site.profile }}/hsk-libs/commit/e1b7fddf0bcf8c5b98f5c62df1f70f6a5d16c3f2#diff-b67911656ef5d18c4ae36cb6741b7965
So far I've been trying to keep everything in `hsk-libs` buildable
with `gmake`, but in favour of compressing the code a lot, I threw
that possibility away, [at least for the docs][commit:hsk-libs/Makefile].

`powerd++`
----------

The `powerd++` daemon is a CPU clock control daemon for FreeBSD:

- [`powerd++` documentation (html)](/powerdxx/)
- [`powerd++` documentation (pdf)](/powerdxx/refman.pdf)

`hsk-libs`
----------

The `hsk-libs` project is an ECU development library for the Infineon
XC878 microcontroller, dating back to my time with [High Speed Karlsruhe]:

- [`hsk-libs` library developer docs (html)](/hsk-libs/dev/)
- [`hsk-libs` library developer docs (pdf)](/hsk-libs/dev/hsk-libs-dev.pdf)
- [`hsk-libs` library user docs (html)](/hsk-libs/user/)
- [`hsk-libs` library user docs (pdf)](/hsk-libs/user/hsk-libs-user.pdf)
- [`hsk-libs` build scripts (html)](/hsk-libs/scripts/)
- [`hsk-libs` build scripts (pdf)](/hsk-libs/scripts/hsk-libs-scripts.pdf)
