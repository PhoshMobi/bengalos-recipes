# Development with immutable images

## Toolbox

Since the `/usr` partition is immutable development differs from traditional distributions.
You can use `toolbox` to get a container, install the necessary build dependencies and build
inside that container image.

To run the container as non-root you need to create the `/etc/subuid` and
`/etc/subgid` files. See
<https://salsa.debian.org/BengalOS-team/bengalos-recipes/-/work_items/16>
for details.

Then get a development container image:

```sh
toolbox create
```

Once downloaded you can install dependencies, build, etc as you're used to
on mutable systems:

```sh
toolbox enter
sudo apt update
```

This can be used to build a library/programm locally so you can put it into
a sysext (see below) afterwards.

## Sysexts

A sysext is overlayed onto the root filesystem. Create the files you want to overlay
under `/var/lib/extensions` e.g. for an extension to test `ucm` profiles:

```console
/var/extensions/
/var/extensions/ucm
/var/extensions/ucm/usr
/var/extensions/ucm/usr/lib
/var/extensions/ucm/usr/lib/extension-release.d
/var/extensions/ucm/usr/lib/extension-release.d/extension-release.ucm
/var/extensions/ucm/usr/share
/var/extensions/ucm/usr/share/alsa
/var/extensions/ucm/usr/share/alsa/ucm2
/var/extensions/ucm/usr/share/alsa/ucm2/Google
/var/extensions/ucm/usr/share/alsa/ucm2/Google/sargo
/var/extensions/ucm/usr/share/alsa/ucm2/Google/sargo/HiFi.conf
/var/extensions/ucm/usr/share/alsa/ucm2/Google/sargo/sargo.conf
/var/extensions/ucm/usr/share/alsa/ucm2/Google/sargo/VoiceCall.conf
```

The `extension-release.ucm` file describes the extension:

```console
$ cat /var/extensions/ucm/usr/lib/extension-release.d/extension-release.ucm
ID=bengalos
VERSION_ID=0.26.0924.1
SYSEXT_LEVEL=1
```

You can get the matching `VERSION_ID` from `/etc/os-info` on your device.
Afterwards you run:

```sh
SYSTEMD_LOG_LEVEL=debug systemd-sysext refresh
```

to activate the extension. By setting the `VERSION_ID` you made sure that
the extension will only apply to this image version and that it will be
disabled automatically on a newer image. If you don't want that look for
`_any` in the systemd-sysext manpage. If you don't want the extension to
be persistent across reboots put it into `/run/extensions` instead.
