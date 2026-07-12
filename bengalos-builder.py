#!/usr/bin/env python3
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2025-2026 Phosh.mobi e.V.
#
# Prepare a BengalOS image build

import argparse
import datetime
import pathlib
import shutil
import sys
import os
import subprocess


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
        version = f"0.{date[2:4]}.{date[4:]}.0"
    filename = dir_path / "mkosi.version"
    print(f"Setting {filename} to {version}")
    with open(filename, "w+") as f:
        f.write(version)


def configure_keys(dir_path: pathlib.Path, blessed: bool):
    """Configure secureboot keys"""
    key = dir_path / "mkosi.key"
    cert = dir_path / "mkosi.crt"
    if blessed:
        if not os.path.exists(key):
            print(f"Signing key {key} missing")
            sys.exit(1)
        if not os.path.exists(cert):
            print(f"Signing key {cert} missing")
            sys.exit(1)
    elif not os.path.exists(key):
        print("Generating new keys…")
        try:
            subprocess.run(["mkosi", "-C", dir_path, "genkey"], check=True)
        except subprocess.CalledProcessError:
            print("Failed to generate keys", file=sys.stderr)
            sys.exit(1)


def copy_dir(src: pathlib.Path, dst: pathlib.Path) -> pathlib.Path:
    path = shutil.copytree(src, dst, dirs_exist_ok=True)
    return pathlib.Path(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("build_directory", type=pathlib.Path, default="build")
    parser.add_argument(
        "--blessed", action="store_true", help="Perform a blessed build"
    )
    parser.add_argument("--clean", action="store_true")

    parser.add_argument("--version", default="")

    args = parser.parse_args()

    return args


def main():
    args = parse_args()
    options = {key.upper(): val for (key, val) in vars(args).items()}

    if args.build_directory.exists():
        if args.clean:
            shutil.rmtree(args.build_directory)

    args.build_directory.mkdir(exist_ok=True)

    src = pathlib.Path("./mkosi.conf.d")
    dst = args.build_directory

    configure_version(args.build_directory, args.version)
    configure_keys(args.build_directory, args.blessed)

    path = copy_dir(src, dst)
    configure_dir(path, options)

    (args.build_directory / "mkosi.cache").mkdir(exist_ok=True)


if __name__ == "__main__":
    main()
