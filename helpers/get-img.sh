#!/bin/bash

set -e

TOPLEVEL=${PWD}
BUCKET=bengalos-staging
TMPDIR="$(mktemp -d)"
TYPE=img
OUTPUT_DIR=.

function cleanup()
{
  cd "$TOPLEVEL"
  [ -z "${TMPDIR}" ] || rm -rf "${TMPDIR}"
}

trap cleanup EXIT

function help()
{
    cat <<EOF
Usage: $0 [-H|--hash] [-t|--type img|qcow2] [-o|--outputdir dir]

Get the image from a staging build

  --hash:             The hash identifying the build
  --type:             Image type to download
  --output-dir:       Output directory, default is $OUTPUT_DIR
EOF
}

while [ -n "$1" ]; do
  case "$1" in
    -h|--help)
        help
        exit 0
        ;;
    -H|--hash)
        shift
        HASH=$1
        ;;
    -t|--type)
        shift
        TYPE=$1
        ;;
    -o|--output-dir)
        shift
        OUTPUT_DIR=$1
        ;;
    *)
        help
        exit 1
  esac
  shift
done


case "$TYPE" in
    img|qcow2)
        ;;
    *)
        echo "Unknown image type $TYPE"
        ;;
esac


function fetch()
{
  local endpoint_url;

  endpoint_url="${AWS_ENDPOINT_URL}/${BUCKET}/staging/${HASH}"
  echo "📥 Fetching ${HASH}…"
  wget -nv -O "${TMPDIR}/hash" "${endpoint_url}/hash" | awk '{ print $2 }'
  sha256sums=$(awk '{ print $2 }' "${TMPDIR}/hash")
  if [ -z "${sha256sums}" ]; then
      echo "Failed to get checksum file"
      exit 1
  fi
  wget -nv -O "${TMPDIR}/SHA256SUMS" "${endpoint_url}/${sha256sums}"
  img_xz=$(awk "/.${TYPE}.xz/ { print \$2 }" "${TMPDIR}/SHA256SUMS" | head -n 1)
  if [ -z "${img_xz}" ]; then
      echo "Failed to get image name"
      exit 1
  fi
  img=$(basename "${img_xz}" .xz)
  echo "📥 Downloading ${img}"
  wget -nv -O- "${endpoint_url}/${img_xz}" | unxz > "${TMPDIR}/${img}"
  mv "${TMPDIR}/${img}" "${OUTPUT_DIR}"
}


if [ -z "${HASH}" ]; then
    echo "No hash given"
    exit 1
fi

if [ -z "${AWS_ENDPOINT_URL}" ]; then
    echo "Need AWS_ENDPOINT_URL"
    exit 1
fi

fetch
