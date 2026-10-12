# BengalOS Design Notes

## Overall guidelines

1. Daily usable is key
1. Simple is more important than flexible
1. Robust is more important than fancy
1. Depth is more important than breadth

## Implementation

### Partitions and Updates

BengalOS use immutable `/usr` partitions that keep the operating systems. At most two versions of
`/usr` exist (*A* and *B*). Each one has a matching UKI that is stored in the ESP partition,
therefore EFI is a requirement, this can be provided by the BIOS or U-Boot. On updates the user
partition and UKI are replaced atomically. If booting fails three times the system falls back to the
old version (e.g. *A* if *B* was updated). Partition discovery and matching of the partitions is
handled via `systemd-dissect`.

The root filesystem carries `/etc` (which should ideally be empty) and `/var` for runtime
data. `/home` is a separate partition that caries each uses home directory, encrypted with its own
key using `systemd-homed`.

### Users

On first boot the system launches a first boot assistant to create the initial user. The initial
user is equipped with the necessary supplementary groups upon first-boot to perform day to day phone
operations. If any of these operations can't be performed it is considered a bug.

The `root` account is locked. It should never be needed, if so it is considered a bug.

### Applications

To install GUI applications the user can use flatpak. The flatpaks and runtimes go into the users
home directory.

To install command line applications one can use toolbox (but note [this issue][subuid]). This
can also be used to build packages, sysexts, etc conveniently.

[subuid]: https://salsa.debian.org/BengalOS-team/bengalos-recipes/-/work_items/16
