#!/usr/bin/env python3

import argparse
import pathlib
import shutil
import sys


def remove_in_suffix(path: pathlib.Path) -> pathlib.Path:
    assert path.suffix == ".in", f"{path} has suffix `{path.suffix}`"
    return path.with_suffix("")


def configure_file(path: pathlib.Path, options: dict[str, str]) -> pathlib.Path:
    print("Configuring", path)
    contents = path.read_text()
    contents = contents.format(**options)
    output = path.rename(remove_in_suffix(path))
    output.write_text(contents)
    return output


def configure_dir(dir_path: pathlib.Path, options: dict[str, str]):
    for path in dir_path.rglob("**/*.in"):
        configure_file(path, options)


def copy_dir(src: pathlib.Path, dst: pathlib.Path) -> pathlib.Path:
    path = shutil.copytree(src, dst / src.name)
    return pathlib.Path(path)


def validate_args(args: argparse.Namespace):
    if args.architecture == "x86-64" and args.device != "amd64":
        sys.exit(
            f"Error: architecutre {args.architecutre} conflicts "
            f"with device {args.device}",
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("build_directory", type=pathlib.Path, default="build")
    parser.add_argument("--clean", action="store_true")

    parser.add_argument("--architecture", choices=["x86-64"], default="x86-64")
    parser.add_argument("--release", choices=["trixie"], default="trixie")
    parser.add_argument("--contrib", action="store_true")
    parser.add_argument("--non_free", action="store_true")

    parser.add_argument("--device", choices=["amd64"], default="amd64")

    parser.add_argument("--hostname", default="phosh")
    parser.add_argument("--username", default="phosh")
    parser.add_argument("--password", default="1234")

    parser.add_argument("--ssh", action="store_true")
    parser.add_argument("--zram", action="store_true")

    args = parser.parse_args()

    return args


def main():
    args = parse_args()
    validate_args(args)
    options = {key.upper(): val for (key, val) in vars(args).items()}

    repositories = ["main"]
    if args.contrib:
        repositories.append("contrib")
    if args.non_free:
        repositories.append("non_free")
    options["REPOSITORIES"] = " ".join(repositories)

    if args.build_directory.exists():
        if args.clean:
            shutil.rmtree(args.build_directory)
    args.build_directory.mkdir()

    src = pathlib.Path("./mkosi.conf.d/")
    dst = args.build_directory / "mkosi.conf.d"

    dst.mkdir()

    path = copy_dir(src / "000-init", dst)
    configure_dir(path, options)

    path = copy_dir(src / "001-device" / args.device, dst)
    path = pathlib.Path(shutil.move(path, dst / f"001-device-{args.device}"))
    configure_dir(path, options)
    if not args.non_free:
        (path / "mkosi.conf.d" / "001-non-free-packages.conf").unlink()

    path = copy_dir(src / "002-system", dst)
    configure_dir(path, options)

    path = copy_dir(src / "003-phosh", dst)
    configure_dir(path, options)

    if args.ssh:
        path = copy_dir(src / "004-ssh", dst)
        configure_dir(path, options)
        # NOTE: 002-system has `etc/tmpfiles.d/chown-home.conf` which shall
        # change the ownership of `.ssh` directory to user. So just make the
        # move here.
        home_src = path / "mkosi.extra" / "home" / "user"
        home_dst = home_src.with_name(args.username)
        shutil.move(home_src, home_dst)

    if args.zram:
        path = copy_dir(src / "004-zram", dst)
        configure_dir(path, options)

    (args.build_directory / "mkosi.cache").mkdir()


if __name__ == "__main__":
    main()
