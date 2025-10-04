# BengalOS

A set of [debos](https://github.com/go-debos/debos) recipes for building a
debian-based image for devices running Phosh.

The default user is `phosh` with password `1234`.

For built images see [here](http://images.phosh.mobi/nightly/). These are meant
for testing the phosh nightly packages.

## Build using `mkosi`

An image can be built using [systemd's mkosi](https://mkosi.systemd.io/). These
images are currently experimental. For debos based builds, see below. You can
install the required packages in a Debian OS as:

``` sh
sudo apt install mkosi --no-install-recommends
```

We suggest not to install recommends as our image is based on Debian and so all
required packages are already present in host OS.

Then setup and build using:

``` sh
./configure.py build --password 1234
mkosi -C build -i
```

You can customize the image through configuration. Check `python3 configure.py
--help` for more information.

The built image is stored in `build/image.raw`. To run Phosh in a VM, you can
use the following command:

``` sh
mkosi -C build vm
```

## Build using debos

To build the image, you need to have `debos` and `bmaptool`. On a Debian-based
system, install these dependencies by typing the following command in a terminal:

``` sh
sudo apt install debos bmap-tools xz-utils zerofree
```

The image builds are currently being performed on Debian Trixie so we recommend
that as a base.

The build system will cache and re-use it's output files. To create a fresh build
remove `*.tar.gz`, `*.sqfs` and `*.img` before starting the build.

If your system isn't debian-based (or if you choose to install `debos` without
using `apt`, which is a terrible idea), please make sure you also install the
following required packages:

- `debootstrap`
- `qemu-system-x86`
- `qemu-user-static`
- `binfmt-support`

Then simply browse to the `phosh-recipes` folder and execute `make amd64`.

## Running

You can start either image with the following command:

```sh
qemu-system-x86_64 -drive format=raw,file=<imagefile.img> -enable-kvm \
    -cpu host -vga virtio -m 2048 -smp cores=4 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd
```

UEFI firmware files are available in Debian thanks to the
[OVMF](https://packages.debian.org/sid/all/ovmf/filelist) package.
Comprehensive explanation about firmware files can be found at
[OVMF project's repository](https://github.com/tianocore/edk2/tree/master/OvmfPkg).

If you prefer libvirt related tooling use:

```sh
virt-install --connect qemu:///session --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,loader_secure=no --vcpus=4 --memory=4096 --osinfo debiantesting -n bengal-os --video qxl --transient --import --disk <imagefile.img> --serial pty
```

You may also want to convert the raw image to qcow2 format
and resize it like this:

```sh
qemu-img convert -f raw -O qcow2 <raw_image.img> <qcow_image.qcow2>
qemu-img resize -f qcow2 <qcow_image.qcow2> +20G
```

## Contributing

If you want to help with this project, please have a look at the
[FAQ](https://phosh.mobi/faq/#whats-a-good-way-to-contribute).

In case you need more information, feel free to get in touch with the developers
on [#phosh:phosh.mobi](https://matrix.to/#/#phosh:phosh.mobi).

### Testing the upload

To test if the upload job would pick things up one can use:

```sh
 git push -o ci.variable=PHOSH_IMAGE_UPLOAD=1 -o ci.variable="PHOSH_IMAGE_HOST=doesnotexist"
```

## License

This software is licensed under the terms of the GNU General Public License,
version 3 and based on mobian-recipes from <https://salsa.debian.org/Mobian-team/mobian-recipes>
