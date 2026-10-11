#!/usr/bin/env python3
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Phosh.mobi e.V.
#
# Expire old blessed builds

import argparse
import html
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from string import Template

import boto3

BUCKET = "bengalos-images"
PREFIX = "roaming/x86-64/qemu"

s3 = boto3.client("s3")

BUILD_RE = re.compile(r"BengalOS_(\d\.(\d{2})\.(\d{4})\.\d+)")
VERSION_RE = re.compile(r"BengalOS.*_(?P<version>\d\.(\d{2})\.(\d{4})\.\d+)")


def list_objects(bucket, folder):
    paginator = s3.get_paginator("list_objects_v2")

    objects = []

    for page in paginator.paginate(
        Bucket=bucket,
        Prefix=folder,
    ):
        objects.extend(page.get("Contents", []))

    return objects


def discover_builds(bucket, folder, objects):
    builds = defaultdict(
        lambda: {
            "date": None,
            "keys": [],
        }
    )

    for obj in objects:
        key = obj["Key"]

        if not key.startswith(folder):
            continue

        filename = key.rsplit("/", 1)[-1]

        m = BUILD_RE.match(filename)
        if not m:
            continue

        build_id = m.group(1)

        build_date = datetime.strptime(
            "20" + m.group(2) + m.group(3),
            "%Y%m%d",
        ).replace(tzinfo=timezone.utc)

        builds[build_id]["date"] = build_date
        builds[build_id]["keys"].append(key)

    return builds


def choose_builds_to_keep(builds):
    now = datetime.now(timezone.utc)

    entries = [
        {
            "build_id": build_id,
            "date": info["date"],
        }
        for build_id, info in builds.items()
    ]

    entries.sort(
        key=lambda x: x["date"],
        reverse=True,
    )

    keep = set()

    # latest 5 builds
    for entry in entries[:5]:
        keep.add(entry["build_id"])

    weekly_cutoff = now - timedelta(days=30)
    yearly_cutoff = now - timedelta(days=365)

    # weekly retention
    weekly = {}

    for entry in entries:
        d = entry["date"]

        if d < weekly_cutoff:
            continue

        key = d.isocalendar()[:2]  # (year, week)

        weekly.setdefault(key, entry)

    for entry in weekly.values():
        keep.add(entry["build_id"])

    # monthly retention
    monthly = {}

    for entry in entries:
        d = entry["date"]

        if d >= weekly_cutoff:
            continue

        if d < yearly_cutoff:
            continue

        key = (d.year, d.month)

        monthly.setdefault(key, entry)

    for entry in monthly.values():
        keep.add(entry["build_id"])

    # yearly retention
    yearly = {}

    for entry in entries:
        d = entry["date"]

        if d >= yearly_cutoff:
            continue

        yearly.setdefault(d.year, entry)

    for entry in yearly.values():
        keep.add(entry["build_id"])

    return keep


def update_index(tmpdir, endpoint, bucket, folder, dry_run):
    source = Path(__file__).parent / "index.html"
    output = Path(tmpdir)

    files = []

    with (output / "SHA256SUMS").open(encoding="utf-8") as checksums:
        for line in checksums:
            if not line.strip():
                continue

            checksum, name = line.rstrip("\n").split(maxsplit=1)
            name = name.removeprefix("*")
            m = VERSION_RE.match(name)
            version = m.group("version") if m else ""

            files.append({
                "name": name,
                "checksum": checksum,
                "version": version
            })

    # Sort by version, then by name
    files.sort(
        key=lambda f: (f["version"].casefold(), f["name"].casefold()),
        reverse=True,
    )

    rows = []
    current_version = ""
    for file in files:
        name = html.escape(file["name"])
        checksum = html.escape(file["checksum"])
        version = file["version"]

        if version != current_version:
            current_version = version
            tr_class = "version_start"
        else:
            tr_class = ""

        rows.append(f"""      <tr class="{tr_class}">
            <td><a href="./{name}">{name}</a></td>
            <td class="checksum">
              <code>{checksum}</code>
            </td>
          </tr>""")

    template = Template(
        (source / "index.html").read_text(encoding="utf-8")
    )

    page = template.substitute(
        title=html.escape(f"{bucket}/{folder}/"),
        rows="\n".join(rows),
        css=(source / "styles.css").read_text(encoding="utf-8"),
    )

    (output / "index.html").write_text(page, encoding="utf-8")

    if dry_run:
        return 0

    print("Uploading new checksum files")
    s3.upload_file(f"{tmpdir}/index.html", bucket, f"{folder}/index.html", ExtraArgs={"ContentType": "text/html"})


def delete_old_builds(bucket, folder, builds, keep, dry_run):
    objects_to_delete = []

    for build_id, info in builds.items():
        if build_id in keep:
            continue

        for key in info["keys"]:
            objects_to_delete.append(key)

    if not objects_to_delete:
        print("Nothing to delete")
        return False

    print(f"Deleting {len(objects_to_delete)} objects")

    if dry_run:
        for obj in objects_to_delete:
            print("DELETE", obj)
        return True

    for obj in objects_to_delete:
        print(f"Deleting {obj}")
        s3.delete_object(Bucket=bucket, Key=obj)

    return True


def update_sha256sums(endpoint, bucket, folder, to_keep, keyid, dry_run):
    with tempfile.TemporaryDirectory() as tmpdir:

        s3.download_file(bucket, f"{folder}/SHA256SUMS", f"{tmpdir}/SHA256SUMS.old")

        s3.download_file(
            bucket, f"{folder}/SHA256SUMS.gpg", f"{tmpdir}/SHA256SUMS.old.gpg"
        )

        try:
            subprocess.run(
                [
                    "gpg",
                    "--verify",
                    f"{tmpdir}/SHA256SUMS.old.gpg",
                    f"{tmpdir}/SHA256SUMS.old",
                ],
                check=True,
            )
        except subprocess.CalledProcessError:
            print("Failed to verify SHA256SUMS signature", file=sys.stderr)
            return 1

        sha256sums = open(f"{tmpdir}/SHA256SUMS.old").read()
        keep = []

        for line in sha256sums.splitlines():
            m = BUILD_RE.search(line)
            # Other files that might be in the index
            if not m:
                keep.append(line)
                continue

            build_id = m.group(1)
            if build_id in to_keep:
                keep.append(line)

        new_sha256sums = "\n".join(keep) + "\n"

        with open(f"{tmpdir}/SHA256SUMS", "w") as out:
            out.write(new_sha256sums)

        try:
            subprocess.run(
                [
                    "gpg",
                    "--sign",
                    f"--default-key={keyid}",
                    "--detach-sign",
                    "--armor",
                    "-o",
                    f"{tmpdir}/SHA256SUMS.gpg",
                    f"{tmpdir}/SHA256SUMS",
                ],
                check=True,
            )
        except subprocess.CalledProcessError:
            print("Failed to sign SHA256SUMS", file=sys.stderr)
            return 1

        if dry_run:
            print("\nNew SHA256SUMS:")
            print(f"{new_sha256sums}")
        else:
            print("Uploading new checksum files")
            s3.upload_file(f"{tmpdir}/SHA256SUMS", bucket, f"{folder}/SHA256SUMS")
            s3.upload_file(f"{tmpdir}/SHA256SUMS.gpg", bucket, f"{folder}/SHA256SUMS.gpg")

            # TODO: Current systemd looks at SHA256SUMS.sha256.asc.
            # Recheck with systemd 261 and file issue if still present
            copy_source = {"Bucket": bucket, "Key": f"{folder}/SHA256SUMS.gpg"}

            s3.copy_object(
                Bucket=bucket, CopySource=copy_source, Key=f"{folder}/SHA256SUMS.sha256.asc"
            )
            print("Cleanup done.")

        update_index(tmpdir, endpoint, bucket, folder, dry_run)

        return 0


def main():
    parser = argparse.ArgumentParser(description="Expire old BengalOS images")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Don't expire anything, just print what would happen",
    )
    parser.add_argument(
        "--folder", type=str, default=PREFIX, help="folder to run expiry in"
    )
    parser.add_argument(
        "--bucket", type=str, default=BUCKET, help="bucket to run expiry in"
    )
    parser.add_argument(
        "--refresh", action="store_true", help="Refresh checksum and index even when nothing changed",
    )
    args = parser.parse_args()

    endpoint = os.getenv("AWS_ENDPOINT_URL")
    if endpoint is None:
        print("No AWS_ENDPOINT_URL")
        return 1
    print(f"Using AWS_ENDPOINT_URL {endpoint}")

    region = os.getenv("AWS_DEFAULT_REGION")
    if region is None:
        print("No AWS_DEFAULT_REGION")
        return 1
    print(f"Using AWS_DEFAULT_REGION {region}")

    if os.getenv("AWS_ACCESS_KEY_ID") is None:
        print("No AWS_ACCESS_KEY_ID")
        return 1

    if os.getenv("AWS_SECRET_ACCESS_KEY") is None:
        print("No AWS_SECRET_ACCESS_KEY")
        return 1

    keyid = os.getenv("BENGALOS_SIGNING_KEY")
    if keyid is None:
        print("No BENGALOS_SIGNING_KEY")
        return 1

    objects = list_objects(args.bucket, args.folder)
    builds = discover_builds(args.bucket, args.folder, objects)
    keep = choose_builds_to_keep(builds)

    print("Keeping builds:")
    for build_id in sorted(keep):
        print(" ", build_id)

    print()
    deleted = delete_old_builds(args.bucket, args.folder, builds, keep, args.dry_run)
    if deleted or args.refresh:
        ret = update_sha256sums(endpoint, args.bucket, args.folder, keep, keyid, args.dry_run)
    else:
        ret = 0

    return ret


if __name__ == "__main__":
    sys.exit(main())
