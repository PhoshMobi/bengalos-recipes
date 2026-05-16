# BengalOS

A set of [mkosi](https://mkosi.systemd.io/) recipes for building a Debian-based image for devices
running Phosh.

There are two kinds of images. The mutable ones that can be useful if you want
to make changes to configurations or packages easily and the immutable ones
supporting atomic updates and rollbacks giving a more phone-like update
behavior. Both images start a first-boot wizard to create the initial user.

> [!important]
> All images contain a `root` user with a default password. Make sure to change that
> when you're doing more than a quick test.

## Immutable Images

The immutable images are what one expects from a phone-like operating system. The
`/usr/` partition is read only and the users are expected to make all their change
in their home directory. This allows us to support atomic A/B updates. The system
will fallback to the old image after 3 failed boots.

For already built images see [here](https://bengalos.phosh.mobi/nightly/).

### Building the Immutable Image

Note that these images are currently experimental and meant for use in virtual
machines only. You can install the required packages in a Debian OS as:

``` sh
sudo apt install mkosi
```

Then setup and build using:

``` sh
make bengalos-amd64-immutable
```

### Running the Immutable Image

The built image is stored in `BengalOS_<version>.raw`. To run the image in a VM, you can use
the following command:

``` sh
make bengalos-amd64-immutable-run
```

If you prefer libvirt related tooling use:

```sh
truncate -s 20G <imagefile.img>
virt-install --connect qemu:///session --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,loader_secure=no --vcpus=4 --memory=4096 --osinfo debiantesting -n bengalos --video qxl --transient --import --disk <imagefile.img> --serial pty
```

You can update the image at any time by running

```sh
/usr/lib/systemd-sysupdate update
```

## Mutable Images

For already built images see [here](https://images.phosh.mobi/nightly/). These are meant for testing
the Phosh nightly packages. We usually refer to the mutable images as
`development` images.

### Building the Mutable Image

Note that these images are currently experimental and meant for use in virtual machines only. You
can install the required packages in a Debian OS as:

``` sh
sudo apt install mkosi
```

Then setup and build using:

``` sh
make bengalos-amd64-development
```

### Running the Mutable Image

The built image is stored in `BengalOS_<version>.raw`. To run the image in a VM, you can use
the following command:

``` sh
bengalos-amd64-development-run
```

If you prefer libvirt related tooling use:

```sh
truncate -s 20G <imagefile.img>
virt-install --connect qemu:///session --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,loader_secure=no --vcpus=4 --memory=4096 --osinfo debiantesting -n bengalos-dev --video qxl --transient --import --disk <imagefile.img> --serial pty
```

To access the serial console in that image you can use

```sh
virsh console bengalos-dev
```

The user is `phosh` with password `1234`. You can update this image using
Debian's tooling like `apt`.

## Troubleshooting

For troubleshooting you can access the virtual machines serial console. If you're using virt-install
as described above you can access the console with

```sh
virsh console bengalos
```

The user is `root` with password `root`.

## Contributing

If you want to help with this project, please have a look at the [Contributors
manual](https://dev.phosh.mobi/docs/).

In case you need more information, feel free to get in touch with the developers on
[#bengalos:phosh.mobi](https://matrix.to/#/#bengalos:phosh.mobi).

The issue tracker is at <https://salsa.debian.org/BengalOS-team/bengalos-recipes/issues/>

For more documentations see [docs/][./docs].

## License

This software is licensed under the terms of the GNU General Public License version 3.
