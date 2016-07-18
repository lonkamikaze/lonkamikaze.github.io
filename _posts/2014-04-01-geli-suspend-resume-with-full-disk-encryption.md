---
title: geli suspend/resume with Full Disk Encryption
update: 2016-07-13
journal: 1
tags:
- FreeBSD
- shell-scripting
- geli
---
This article details my solution of the `geli resume` deadlock. It
is the result of much fiddling and locking myself out of the file
system.

{% include man.md p="geli" s=8 %}
{% include man.md p="getty" s=8 %}
{% include man.md p="init" s=8 %}
{% include man.md p="nullfs" s=5 %}
{% include man.md p="tmpfs" s=5 %}

<div class="note">
	<h4>Note</h4>
	<p>
		This article was revised {{ page.update }},
		when it was transferred from Blogger. The original
		article can
		<a href="https://angryswarm.blogspot.com/2014/03/geli-suspendresume-with-fulll-disk.html">still be found</a>.
	</p>
</div>

<div class="note warn">
	<h4>Warning</h4>
	<p>
		The presented solution works most of the time, but
		it is still possible to deadlock the system.
	</p>
</div>

After my good old HP6510b notebook was stolen I decided to set up
full disk encryption for its replacement. However after I set it up
I faced the problem that the device would be wide open after resuming
from suspend. That said I rarely reboot my system, I usually keep
everything open permanently and suspend the laptop for transport or
extended non-use. So the problem is quite severe.

Luckily the [FreeBSD](https://www.freebsd.org/) encryption solution
[geli(8)] provides a mechanism called `geli suspend` that deletes
the key from memory and stalls all processes trying to access the
file system.  Unfortunately `geli resume` would be one such process.


The System
----------

So first things first, a quick overview of the system. If you ever
set up full disk encryption yourself, you can probably skip ahead.

The boot partition containing the boot configuration, the kernel and
its modules is not encrypted. It resides in the device `ada0p2` labelled
`gpt/6boot`. The encrypted device is `ada0p4` labelled `6root`. For
easy maintenance and use the `6boot:/boot` directory is mounted into
`6root.eli:/boot` (the `.eli` marks an attached encrypted device).
Because `/boot` is a subdirectory in the `6boot` file system, a
[nullfs(5)] mount is required to access `6boot:/boot` and mount it
into `6root:/boot`. To access `6boot:/boot`, `6boot` is mounted into
`/mnt/boot`.

Usually `mount` automatically loads the required modules when invoked,
but this doesn't work when the root file system doesn't contain them.
So the required modules need to be loaded during the loader stage.

~~~ sh
# Encrypted root file system
vfs.root.mountfrom="ufs:gpt/6root.eli"
geom_eli_load="YES"                     # FS crypto
aesni_load="YES"                        # Hardware AES

# Allow nullfs mounting /boot
nullfs_load="YES"
tmpfs_load="YES"
~~~
`/boot/loader.conf`

~~~ conf
# Device           Mountpoint   FStype Options    Dump Pass
/dev/gpt/6root.eli /            ufs    rw,noatime 1    1
/dev/gpt/6boot     /mnt/boot    ufs    rw,noatime 1    1
/mnt/boot/boot     /boot        nullfs rw         0    0
/dev/gpt/6swap.eli none         swap   sw         0    0
# Temporary files
tmpfs              /tmp         tmpfs  rw         0    0
tmpfs              /var/run     tmpfs  rw         0    0
~~~
`/etc/fstab`

The Problem
-----------

The problem with `geli suspend/resume` is that calling `geli resume ada0p4`
deadlocks, because `geli` is located on the partition that is supposed
to be resumed.

The Approach
------------

The solution is quite simple. Put `geli` somewhere unencrypted.

To implement this several challenges need to be faced:

| Challenge                                                          | Approach                                                         |
|--------------------------------------------------------------------|------------------------------------------------------------------|
| Programming                                                        | Shell-scripting                                                  |
| Technology, avoiding file system access                            | Use [tmpfs(5)]                                                   |
| Usability, how to enter passphrases                                | Use a system console                                             |
| Safety, the solution needs to be running before a suspend          | Use an always on, unauthenticated console                        |
| Security, an unauthenticated interactive service is prone to abuse | Only allow password entry, no other kinds of interactive control |
| Safety, what about accidentally terminating the script             | Ignore SIGINT                                                    |

The challenges and the proposed solutions.

The Script
----------

The complete script can be found at the bottom.

### Constants

At the beginning of the script some read-only variables (the closest
available thing to constants) are defined, mostly for convenience
and to avoid typos.

~~~ sh
#!/bin/sh
set -f

readonly gcdir="/tmp/geliconsole"
readonly dyn="/sbin/geli;/usr/sbin/acpiconf;/usr/sbin/apm"
readonly static="/rescue/sh"
~~~
The front matter.

### Bootstrapping

The script is divided into two parts, the first part is the bootstrapping
section that requires file system access and creates the `tmpfs` with
everything that is needed to resume suspended partitions.

The bootstrap is performed in a conditional block, that checks whether
the script is running from `gcdir`. It ends with calling a copy of
the script. The exec call means the bootstrapping process is replaced
with the new call. The copy of the script will detect that it is running
from the `tmpfs` and skip the bootstrapping:

~~~ sh
# If this process isn't running from the tmpfs, bootstrap
if [ "${0#${gcdir}}" == "$0" ]; then
	…
	# Complete bootstrap
	exec "${gcdir}/sh" "${gcdir}/${0##*/}" "$@"
fi
~~~

A bootstrapping section.

Before completing the bootstrap, the `tmpfs` needs to be set up. Creating
it is a good start:

~~~ sh
	# Create tmpfs
	/bin/mkdir -p "${gcdir}"
	/sbin/mount -t tmpfs tmpfs "$gcdir" || exit 1

	# Create named pipe to control suspend/resume
	/usr/bin/mkfifo "${gcdir}/suspend.fifo"

	# Copy the script before changing into gcdir, $0 might be a
	# relative path
	/bin/cp "$0" "${gcdir}/" || exit 1

	# Enter tmpfs
	cd "${gcdir}" || exit 1
~~~

Create a `tmpfs`.

The next step is to populate it with everything that is needed. I.e.
all binaries required after performing the bootstrap. Two kinds of
binaries are used, statically linked (see the `static` read-only)
and dynamically linked (see the `dyn` read-only).

The static binaries can simply be copied into the `tmpfs`, the dynamically
linked ones also require libraries, a list of which is provided by
[ldd(1)](https://www.freebsd.org/cgi/man.cgi?query=ldd&manpath=FreeBSD+10.0-RELEASE).

Note the use of `IFS` (Input Field Separator) to split variables into
multiple arguments and how subprocesses are used to limit the scope
of `IFS` changes:

~~~ sh
	# Get shared objects
	(IFS='
'
		for lib in $(IFS=';';/usr/bin/ldd -f '%p;%o\n' ${dyn}); do
			(IFS=';' ; /bin/cp ${lib})
		done
	)

	# Get executables
	(IFS=';' ; /bin/cp ${dyn} ${static} "${gcdir}/")
~~~

Copy executables and libraries.

The resulting `tmpfs` contains the binaries `sh`, `geli`, `acpiconf`,
`apm` and all required libraries.

### Interactive Stage

When reaching the interactive stage, the script is already run by
a static shell within the `tmpfs`. The first order of business is
to make sure the shell won't look for executables outside the `tmpfs`:

~~~ sh
export PATH="${gcdir}" LD_LIBRARY_PATH="${gcdir}"
~~~

Do not look for executables outside of the `tmpfs`.

The next step is to trap some signals to make sure the script exits
gracefully:

~~~ sh
signal() {
	while /sbin/umount -f "${gcdir}" 2> /dev/null; do :; done
	exit 0
}

trap 'echo geliconsole: Exiting' EXIT
trap 'signal' SIGTERM SIGINT SIGHUP
~~~

Clean up and terminate for the common signals.

The last chunk of code waits for input from the named pipe. Any input
triggers the supspend/resume activity, by suspending geli devices and
immediately starting the resume procedure, which asks for passphrase
entry of the first suspended device until it runs out of suspended
devices.


~~~ sh
have_suspended_geoms() {
	local list
	list="$("${gcdir}/geli" list)"
	test -z "${list##*State: SUSPENDED*}"
}

echo "geliconsole: Activated"
while read -r subsystem < "${gcdir}/suspend.fifo"; do
	trap '' SIGTERM SIGINT SIGHUP
	echo "geliconsole: Suspend"
	"${gcdir}/geli" suspend -a
	if [ $subsystem = "apm" ]; then
		"${gcdir}/apm" -z &
	else
		"${gcdir}/acpiconf" -k 0 &
	fi
	# Resume
	while have_suspended_geoms; do
		geom="$("${gcdir}/geli" list)"
		geom="${geom%%State: SUSPENDED*}"
		geom="${geom##*Geom name: }"
		geom="${geom%%.eli*}"
		echo "geliconsole: Resume $geom"
		"${gcdir}/geli" resume "$geom"
		echo .
	done
	trap 'signal' SIGTERM SIGINT SIGHUP
	echo "geliconsole: Resumed"
done
~~~
Device suspension and recovery.

The System Console
------------------

Because the script does not take care of grabbing the right console,
it cannot simply be run from `/etc/ttys`. Instead it needs to be started
by [getty(8)]. To do this a new entry into `/etc/gettytab` is required:

~~~ conf
#
# geliconsole
#
geliconsole|gc.9600:\
	:al=root:tc=std.9600:lo=/root/bin/geliconsole:
~~~
Define the `geliconsole` terminal.

The entry defines a new terminal type called `geliconsole` with auto
login.

The new *terminal* can now be started by the [init(8)] process by
adding the following line to `/etc/ttys`:

~~~ conf
ttyvb "/usr/libexec/getty geliconsole" xterm on  secure
~~~
Put the `geliconsole` terminal on console 11.

With `kill -HUP 1` the init process can be notified of the change. 

The console should now be available on console 11 (`CTRL+ALT+F12`)
and look similar to this:

~~~
FreeBSD/amd64 (AprilRyan.norad) (ttyvb)

geliconsole: Activated
~~~
The `geliconsole` is waiting for activity on the named pipe.

Suspending
----------

In order to automatically suspend disks, update `/etc/rc.suspend`:

~~~ diff
--- /usr/src/etc/rc.suspend     2014-03-12 14:04:02.000000000 +0100
+++ /etc/rc.suspend     2016-07-12 20:30:30.110803000 +0200
@@ -54,14 +54,14 @@

 /usr/bin/logger -t $subsystem suspend at `/bin/date +'%Y%m%d %H:%M:%S'`
 /bin/sync && /bin/sync && /bin/sync
+if ! /usr/sbin/vidcontrol -s 12 <> /dev/ttyv0; then
+       /usr/sbin/acpiconf -k 1
+       /usr/bin/logger -t $subsystem suspend canceled, geliconsole not available
+       exit 1
+fi
 /bin/sleep 3

 /bin/rm -f /var/run/rc.suspend.pid
-if [ $subsystem = "apm" ]; then
-       /usr/sbin/zzz
-else
-       # Notify the kernel to continue the suspend process
-       /usr/sbin/acpiconf -k 0
-fi
+echo $subsystem > /tmp/geliconsole/suspend.fifo

 exit 0
~~~
Use `geliconsole` to finalise suspend and cancel if not available.

The `vidcontrol -s 12` command VT-switches to the geli console, before
 the `geli` command suspends all encrypted partitions.

In order for the VT-switch to work without flaw, the automatic VT
 switch to console 0 needs to be turned off:

~~~ sh
sysctl hw.syscons.sc_no_suspend_vtswitch=1
echo hw.syscons.sc_no_suspend_vtswitch=1 >> /etc/sysctl.conf
~~~

Desirable Improvements
----------------------

For people running X, especially with a version where X breaks the
console, it would be nice to enter the keywords through a screen locker.

Also it is not really necessary to run the script with root privileges.
 A dedicated, less privileged user account, should be created and used.

Files
-----

~~~ sh
#!/bin/sh
set -f

readonly gcdir="/tmp/geliconsole"
readonly dyn="/sbin/geli;/usr/sbin/acpiconf;/usr/sbin/apm"
readonly static="/rescue/sh"

# If this process isn't running from the tmpfs, bootstrap
if [ "${0#${gcdir}}" == "$0" ]; then
	# Remove old tmpfs
	while /sbin/umount -f '${gcdir}' 2> /dev/null; do :; done
	# Create tmpfs
	/bin/mkdir -p "${gcdir}"
	/sbin/mount -t tmpfs tmpfs "$gcdir" || exit 1

	# Create a named pipe to control suspend/resume
	/usr/bin/mkfifo "${gcdir}/suspend.fifo"

	# Copy the script before changing into gcdir, $0 might be a
	# relative path
	/bin/cp "$0" "${gcdir}/" || exit 1

	# Enter tmpfs
	cd "${gcdir}" || exit 1

	# Get shared objects
	(IFS='
'
		for lib in $(IFS=';';/usr/bin/ldd -f '%p;%o\n' ${dyn}); do
			(IFS=';' ; /bin/cp ${lib})
		done
	)

	# Get executables
	(IFS=';' ; /bin/cp ${dyn} ${static} "${gcdir}/")

	# Complete bootstrap
	exec "${gcdir}/sh" "${gcdir}/${0##*/}" "$@"
fi

export PATH="${gcdir}" LD_LIBRARY_PATH="${gcdir}"

signal() {
	while /sbin/umount -f "${gcdir}" 2> /dev/null; do :; done
	exit 0
}

trap 'echo geliconsole: Exiting' EXIT
trap 'signal' SIGTERM SIGINT SIGHUP
echo $$ > "${gcdir}/pid"

have_suspended_geoms() {
	local list
	list="$("${gcdir}/geli" list)"
	test -z "${list##*State: SUSPENDED*}"
}

echo "geliconsole: Activated"
echo "geliconsole: version 3"
while read -r subsystem < "${gcdir}/suspend.fifo"; do
	trap '' SIGTERM SIGINT SIGHUP
	echo "geliconsole: Suspend"
	"${gcdir}/geli" suspend -a
	if [ $subsystem = "apm" ]; then
		"${gcdir}/apm" -z &
	else
		"${gcdir}/acpiconf" -k 0 &
	fi
	# Resume
	while have_suspended_geoms; do
		geom="$("${gcdir}/geli" list)"
		geom="${geom%%State: SUSPENDED*}"
		geom="${geom##*Geom name: }"
		geom="${geom%%.eli*}"
		echo "geliconsole: Resume $geom"
		"${gcdir}/geli" resume "$geom"
		echo .
	done
	trap 'signal' SIGTERM SIGINT SIGHUP
	echo "geliconsole: Resumed"
done
~~~
`/root/bin/geliconsole`

