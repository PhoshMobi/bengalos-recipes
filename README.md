# BengalOS

A set of [mkosi](https://mkosi.systemd.io/) recipes for building a Debian-based image for devices
running Phosh.

The default user is `phosh` with password `1234`.

For already built images see [here](http://images.phosh.mobi/nightly/). These are meant for testing
the Phosh nightly packages.

## Building

Note that these images are currently experimental and meant for use in virtual machines only. You
can install the required packages in a Debian OS as:

``` sh
sudo apt install mkosi
```

Then setup and build using:

``` sh
make bengalos-amd64-development
```

## Running

The built image is stored in `BengalOS-amd64_<version>.raw`. To run the image in a VM, you can use
the following command:

``` sh
bengalos-amd64-development-run
```

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

If you want to help with this project, please have a look at the [Contributors
manual](https://dev.phosh.mobi/docs/).

In case you need more information, feel free to get in touch with the developers on
[#phosh:phosh.mobi](https://matrix.to/#/#phosh:phosh.mobi).

### Testing the CI upload

To test if the upload part of the CI job would pick things up correctly one can use:

```sh
 git push -o ci.variable=PHOSH_IMAGE_UPLOAD=1 -o ci.variable="PHOSH_IMAGE_HOST=doesnotexist"
```

## License

This software is licensed under the terms of the GNU General Public License version 3.
