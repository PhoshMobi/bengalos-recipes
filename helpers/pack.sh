#!/bin/bash

set -e

TOPLEVEL=${PWD}
DEVICE=amd64
UPLOAD_ONLY=0

function cleanup()
{
    cd "$TOPLEVEL"
}

trap cleanup EXIT

function help()
{
    cat <<EOF
Usage: $0 [-d|--device device] [--u|--upload-host hostname] [-U|--upload-only]

Pack and upload immutable BengalOS images

  --device:      The device type (e.g. amd64)
  --upload-host: The host to upload to
  --upload-only: Only upload, don't pack
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
    -u|--upload-host)
	shift
	UPLOAD_HOST=$1
        ;;
    -U|--upload-only)
	UPLOAD_ONLY=1
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

  for part in qcow2 raw usr.raw usr-verity.raw usr-verity-sig.raw efi; do
    local base="BengalOS_${VERSION}.${part}"
    local compressed="${VERSION}/BengalOS_${VERSION}.${part}.xz"
    echo "📦 Creating ${compressed}…"
    xz --stdout "${base}" > "${compressed}.temp"
    mv "${compressed}.temp" "${compressed}"
  done
  cp "BengalOS_${VERSION}.osrelease" "${VERSION}"

  cd "${VERSION}"
  sha256sum BengalOS_*.xz > "${VERSION}.SHA256SUMS.tmp"
  mv "${VERSION}.SHA256SUMS.tmp" "${VERSION}.SHA256SUMS"
}

function upload() {
  local target="${UPLOAD_HOST}/${DEVICE}/base/dump/"

  cd "${TOPLEVEL}/build-${DEVICE}-immutable/${VERSION}"
  echo "⤴️ Uploading images to ${target}…"
  rsync --recursive --progress --verbose ./* "${target}/"
}

function mk_qcow2() {
  local raw="BengalOS_${VERSION}.raw"
  local qcow2="BengalOS_${VERSION}.qcow2"

  prep

  echo "🐄 Creating qcow2 image…"
  qemu-img convert -f raw -O qcow2 "${raw}" "${qcow2}"
  qemu-img resize -q -f qcow2 "${qcow2}" 20G
}

[ "${UPLOAD_ONLY}" == 1 ] || mk_qcow2
[ "${UPLOAD_ONLY}" == 1 ] || pack
[ -z "${UPLOAD_HOST}" ] || upload
