#!/usr/bin/env python3

import argparse
import datetime
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


def configure_version(dir_path: pathlib.Path, version: str):
    if not version:
        date = datetime.datetime.today().strftime("%Y%m%d")
        version = f"0.0.{date}.0"
    filename = dir_path / "mkosi.version"
    print(f"Setting {filename} to {version}")
    with open(filename, "w+") as f:
        f.write(version)


def copy_dir(src: pathlib.Path, dst: pathlib.Path) -> pathlib.Path:
    path = shutil.copytree(src, dst, dirs_exist_ok=True)
    return pathlib.Path(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("build_directory", type=pathlib.Path, default="build")
    parser.add_argument("--clean", action="store_true")

    parser.add_argument("--username", default="phosh")
    parser.add_argument("--password", default="1234")

    parser.add_argument("--version", default="")

    args = parser.parse_args()

    return args


def main():
    args = parse_args()
    options = {key.upper(): val for (key, val) in vars(args).items()}

    if args.build_directory.exists():
        if args.clean:
            shutil.rmtree(args.build_directory)
        else:
            print(
                f"Build directory `{args.build_directory}` already exists, "
                "either delete it and configure again or pass `--clean`.",
                file=sys.stderr,
            )
            sys.exit(1)
    args.build_directory.mkdir()

    src = pathlib.Path("./mkosi.conf.d")
    dst = args.build_directory

    configure_version(args.build_directory, args.version)

    path = copy_dir(src, dst)
    configure_dir(path, options)


    (args.build_directory / "mkosi.cache").mkdir()


if __name__ == "__main__":
    main()
