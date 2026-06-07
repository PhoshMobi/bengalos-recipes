# Development with immutable images

Since the `/usr` partition is immutable development differs from traditional distributions.
You can use `toolbox` to get a container, install the necessary build dependencies and built
inside that container image.

First add a policy for podman. E.g. this allows to pull from everywhere:

```sh
mkdir -p ~/.config/containers/
cat <<EOF > ~/.config/containers/policy.json
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
EOF
```

Then get a development container image:

```sh
toolbox create
```

Once downloaded you can install dependencies, build, etc as you're used to
on mutable systems:

```sh
toolbox enter
```

To run the container as non-root you need to create the `/etc/subuid` and
`/etc/subgid` files. See
<https://salsa.debian.org/BengalOS-team/bengalos-recipes/-/work_items/16>
for details.
