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

function pack() {
  cd ${TOPLEVEL}/build-${DEVICE}-immutable
  mkdir -p "${VERSION}"

  for part in raw usr.raw usr-verity.raw usr-verity-sig.raw efi; do
    local base="BengalOS_${VERSION}.${part}"
    local compressed="${VERSION}/BengalOS_${VERSION}.${part}.xz"
    echo "📦 Creating ${compressed}…"
    xz --stdout "${base}" > "${compressed}.temp"
    mv "${compressed}.temp" "${compressed}"
  done
  cp "BengalOS_${VERSION}.osrelease" "${VERSION}"

  cd "${VERSION}"
  sha256sum BengalOS_*.xz > SHA256SUMS
  rm -f SHA256SUMS.gpg
  gpg --output SHA256SUMS.gpg --sign SHA256SUMS
}

function upload() {
  local target="${UPLOAD_HOST}/${DEVICE}/base/dump/"

  cd "${TOPLEVEL}/build-${DEVICE}-immutable/${VERSION}"
  echo "⤴️ Uploading images to ${target}…"
  rsync --recursive --progress --verbose ./* "${target}/"
}

[ "${UPLOAD_ONLY}" == 1 ] || pack
[ -z "${UPLOAD_HOST}" ] || upload
