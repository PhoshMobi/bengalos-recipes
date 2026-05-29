#!/bin/bash

set -e

TOPLEVEL=${PWD}
BUCKET=bengalos-staging
TMPDIR="$(mktemp -d)"
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
Usage: $0 [-H|--hash]

Get the qcow2 from a staging build

  --hash:             The hash identifying the build
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

function fetch()
{
  local endpoint_url;

  endpoint_url="${AWS_ENDPOINT_URL}/${BUCKET}/staging/${HASH}"
  echo "📥 Fetching ${HASH}…"
  wget -O "${TMPDIR}/hash" "${endpoint_url}/hash" | awk '{ print $2 }'
  sha256sums=$(awk '{ print $2 }' "${TMPDIR}/hash")
  if [ -z "${sha256sums}" ]; then
      echo "Failed to get checksum file"
      exit 1
  fi
  wget -O "${TMPDIR}/SHA256SUMS" "${endpoint_url}/${sha256sums}"
  qcow2_xz=$(awk '/.qcow2.xz/ { print $2 }' "${TMPDIR}/SHA256SUMS" | head -n 1)
  if [ -z "${qcow2_xz}" ]; then
      echo "Failed to get qcow name"
      exit 1
  fi
  qcow2=$(basename "${qcow2_xz}" .xz)
  wget -O- "${TMPDIR}/SHA256SUMS" "${endpoint_url}/${qcow2_xz}" | unxz > "${TMPDIR}/${qcow2}"
  mv "${TMPDIR}/${qcow2}" "${OUTPUT_DIR}"
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
