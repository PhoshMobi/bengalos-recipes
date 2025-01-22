# phosh-os-recipes

A set of [debos](https://github.com/go-debos/debos) recipes for building a
debian-based image for devices running Phosh.

The default user is `phosh` with password `1234`.

For built images see [here](http://images.phosh.mobi/nightly/). These are meant
for testing the phosh nightly packages.

## Build

To build the image, you need to have `debos` and `bmaptool`. On a Debian-based
system, install these dependencies by typing the following command in a terminal:

```
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

Then simply browse to the `phosh-os-recipes` folder and execute `./build.sh`.

You can use `./build.sh -d` to use the docker version of `debos`.

### QEMU image

#### Building

You can build a QEMU x86_64 image by adding the `-t amd64` flag to `build.sh`

The resulting files are raw images.

#### Running

You can start qemu like so:

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
virt-install --connect qemu:///session --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,loader_secure=no --vcpus=4 --osinfo debiantesting -n phosh-os --video qxl  --transient --import --disk phosh-os-amd64-phosh-20240401.img
```

You may also want to convert the raw image to qcow2 format
and resize it like this:

```
qemu-img convert -f raw -O qcow2 <raw_image.img> <qcow_image.qcow2>
qemu-img resize -f qcow2 <qcow_image.qcow2> +20G
```

## Contributing

If you want to help with this project, please have a look at the
[FAQ](https://phosh.mobi/faq/#whats-a-good-way-to-contribute).

In case you need more information, feel free to get in touch with the developers
on [#phosh:librem.one](https://matrix.to/#/#phosh:librem.one).

### Testing the upload

To test if the upload job would pick things up one can use:

```sh`
 git push -o ci.variable=PHOSH_IMAGE_UPLOAD=1 -o ci.variable="PHOSH_IMAGE_HOST=doesnotexist"
```

## License

This software is licensed under the terms of the GNU General Public License,
version 3 and based on mobian-recipes from <https://salsa.debian.org/Mobian-team/mobian-recipes>
