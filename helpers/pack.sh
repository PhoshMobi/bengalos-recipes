#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Phosh.mobi e.V.
#
# Pack BengalOS images and upload them to staging

set -e

TOPLEVEL=${PWD}
DEVICE=amd64
UPLOAD_ONLY=0
PACK_ONLY=0
BUCKET=bengalos-staging

function cleanup()
{
  cd "$TOPLEVEL"
}

function err()
{
  echo "❌ Pack & upload failed."
}

trap cleanup EXIT
trap err ERR

function help()
{
    cat <<EOF
Usage: $0 [-d|--device device] [-U|--upload-only] [-P|--pack-only]

Pack and upload immutable BengalOS images

  --device:      The device type (e.g. amd64)
  --upload-only: Upload only, don't pack
  --pack-only:   Pack only, don't upload
EOF
}

while [ -n "$1" ]; do
  case "$1" in
    -h|--help)
        help
        exit 0
        ;;
    -d|--device)
	shift
	DEVICE=$1
        ;;
    -U|--upload-only)
	UPLOAD_ONLY=1
	;;
    -P|--pack-only)
	PACK_ONLY=1
	;;
    *)
	help
	exit 1
  esac
  shift
done

VERSION_FILE="build-${DEVICE}-immutable/mkosi.version"

if [ ! -f "$VERSION_FILE" ]; then
  echo "No version file at $VERSION_FILE"
  exit 1
fi

VERSION=$(cat "$VERSION_FILE")

function prep() {
    cd "${TOPLEVEL}/build-${DEVICE}-immutable"
    mkdir -p "${VERSION}"
}

function pack() {
  prep

  for part in qcow2 usr.raw usr-verity.raw usr-verity-sig.raw efi; do
    local base="BengalOS_${VERSION}.${part}"
    local compressed="${VERSION}/BengalOS_${VERSION}.${part}.xz"
    echo "📦 Creating ${compressed}…"
    xz --stdout "${base}" > "${compressed}.temp"
    mv "${compressed}.temp" "${compressed}"
  done
  cp "BengalOS_${VERSION}.osrelease" "${VERSION}"

  cd "${VERSION}"
  sha256sum BengalOS_*.xz BengalOS_*.osrelease > "${VERSION}.SHA256SUMS.tmp"
  mv "${VERSION}.SHA256SUMS.tmp" "${VERSION}.SHA256SUMS"
}

function upload() {
  cd "${TOPLEVEL}/build-${DEVICE}-immutable/${VERSION}"

  sha256sum "${VERSION}.SHA256SUMS" > 'hash'
  hash=$(awk '{ print $1 }' hash)
  if [ -z "$hash" ]; then
    echo "Failed to calculate hash"
    exit 1
  fi

  echo "🔐 Content hash is ${hash}"
  echo "📤 Uploading to staging…"
  aws s3 cp . "s3://${BUCKET}/staging/${hash}/" --recursive

  echo "✅ Images uploaded to ${BUCKET}"
}

function mk_qcow2() {
  local raw="BengalOS_${VERSION}.raw"
  local qcow2="BengalOS_${VERSION}.qcow2"

  prep

  echo "🐄 Creating qcow2 image…"
  qemu-img convert -f raw -O qcow2 "${raw}" "${qcow2}"
  qemu-img resize -q -f qcow2 "${qcow2}" 20G
}

if [ -z "$AWS_ENDPOINT_URL" ] && [ "${PACK_ONLY}" -eq 0 ]; then
    echo "Need AWS_ENDPOINT_URL."
    exit 1
else
    echo "Using endppoint ${AWS_ENDPOINT_URL}"
fi

if [ -z "$AWS_DEFAULT_REGION" ] && [ "${PACK_ONLY}" -eq 0 ]; then
    echo "Need AWS_DEFAULT_REGION."
    exit 1
else
    echo "Using region ${AWS_DEFAULT_REGION}"
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] && [ "${PACK_ONLY}" -eq 0 ]; then
    echo "Need AWS_ACCESS_KEY_ID."
    exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ] && [ "${PACK_ONLY}" -eq 0 ]; then
    echo "Need AWS_SECRET_ACCESS_KEY."
    exit 1
fi

[ "${UPLOAD_ONLY}" == 1 ] || mk_qcow2
[ "${UPLOAD_ONLY}" == 1 ] || pack
[ "${PACK_ONLY}" == 1 ] || upload
