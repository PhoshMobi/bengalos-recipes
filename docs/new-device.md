# Adding support for a new device

If the generic device type is already supported (e.g. `sdm670` or `sdm845`):

- Add the device tree to the device-types `Devicetrees` of that device type
- Add the GPU firmware to the `bengalos-firmware` package
- If needed, add kernel options to the kernel config in `bengalos-debs`
- Add UCM profiles to the `bengalos` package for audio support

To test the image you can add the kernel and firmware package to `mkosi.conf.d/mkosi.packages` and
change the device type's `mkosi.conf` `Packages=` to include these packages like:

```ini
[Content]
Packages=
        linux-image-<yourkernel>=<debian-package-version>
        bengalos-firmware-qcom=<debian-package-version>
```

If it is a complete new SoC add a device profile based on one of the existing ones.
