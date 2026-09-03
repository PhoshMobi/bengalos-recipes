# Development with immutable images

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
