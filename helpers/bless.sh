#!/bin/bash

set -e

TOPLEVEL=${PWD}
STAGING_BUCKET=bengalos-staging
STAGING_PREFIX=staging
BLESSED_BUCKET=bengalos-images
TMPDIR="$(mktemp -d)"
# TODO: get from metainfo
ARCH=x86-64

function cleanup()
{
  cd "$TOPLEVEL"
  [ -z "${TMPDIR}" ] || rm -rf "${TMPDIR}"
}


function err()
{
  echo "❌ Publish failed."
}

trap cleanup EXIT
trap err ERR

function help()
{
    cat <<EOF
Usage: $0 [-h|--hash hash]

Bless an immutable image

  --hash:             The manifests's hash of the to bless images
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
    *)
	help
	exit 1
  esac
  shift
done


function bless()
{
  local sha256sums
  local osrelease
  local blessed_prefix

  echo "📥 Fetching metainfo from staging…"

  aws s3 cp \
      "s3://${STAGING_BUCKET}/${STAGING_PREFIX}/${HASH}/hash" \
      "${TMPDIR}/hash" \
      --only-show-errors

  # Get checksum file
  sha256sums=$(awk '{ print $2 }' "${TMPDIR}/hash")

  if [ -z "${sha256sums}" ]; then
      echo "Can't find checksum file in metanfo"
      exit 1
  fi

  aws s3 cp \
      "s3://${STAGING_BUCKET}/${STAGING_PREFIX}/${HASH}/${sha256sums}" \
      "${TMPDIR}/${sha256sums}" \
      --only-show-errors

  echo "🔐 Verifying checksum file integrity…"

  {
    cd "${TMPDIR}"
    if ! sha256sum -c hash; then
      echo "Checksum of ${sha256sums} invalid"
      exit 1
    fi
  }

  # Get osrelease
  osrelease=$(awk '/.osrelease/ { print $2 }' "${TMPDIR}/${sha256sums}")
  aws s3 cp \
      "s3://${STAGING_BUCKET}/${STAGING_PREFIX}/${HASH}/${osrelease}" \
      "${TMPDIR}/${osrelease}" \
      --only-show-errors
  # shellcheck source=/dev/null
  . "${TMPDIR}/${osrelease}"

  if [ -z "${VARIANT_ID}" ]; then
      echo "No VARIANT_ID in metainfo"
      exit 1
  fi

  if [ -z "${VERSION_CODENAME}" ]; then
      echo "No VERSION_CODENAME in metainfo"
      exit 1
  fi

  blessed_prefix="${VERSION_CODENAME}/${ARCH}/${VARIANT_ID}"

  echo "📦 Publishing artifacts to blessed bucket…"

  # Copy each artifact listed in checksum file
  awk '{ print $2 }' "${TMPDIR}/${sha256sums}" | while IFS= read -r file; do
      echo "  → ${file}"

      aws s3 cp \
          "s3://${STAGING_BUCKET}/${STAGING_PREFIX}/${HASH}/${file}" \
          "s3://${BLESSED_BUCKET}/${blessed_prefix}/${file}" \
          --only-show-errors
  done

  echo "📄 Updating global SHA256SUMS index…"
  # Fetch existing index
  aws s3 cp \
      "s3://${BLESSED_BUCKET}/${blessed_prefix}/SHA256SUMS" \
      "${TMPDIR}/SHA256SUMS" \
      --only-show-errors \
      || touch "${TMPDIR}/SHA256SUMS"

  mv "${TMPDIR}/SHA256SUMS" "${TMPDIR}/SHA256SUMS".tmp
  cat "${TMPDIR}/${sha256sums}" >> "${TMPDIR}/SHA256SUMS".tmp
  mv "${TMPDIR}/SHA256SUMS".tmp "${TMPDIR}/SHA256SUMS"

  # Upload updated index
  aws s3 cp \
      "${TMPDIR}/SHA256SUMS" \
      "s3://${BLESSED_BUCKET}/${blessed_prefix}/SHA256SUMS" \
      --only-show-errors

  # Update latest images
  qcow2=$(awk '/.qcow2.xz/ { print $2 }' "${TMPDIR}/${sha256sums}" | head -n 1)
  # Not all architectures have qcow2 images:
  if [ -n "${qcow2}" ]; then
      echo "📌 Pinning latest image…"
      echo "  → ${qcow2}"
      aws s3 cp \
          "s3://${BLESSED_BUCKET}/${blessed_prefix}/${qcow2}" \
          "s3://${BLESSED_BUCKET}/${blessed_prefix}/latest.qcow2.xz" \
          --only-show-errors
  fi

  echo "✅ Publish complete for ${HASH}"
}

if [ -z "$AWS_ENDPOINT_URL" ]; then
    echo "Need AWS_ENDPOINT_URL."
    exit 1
else
    echo "Using endppoint ${AWS_ENDPOINT_URL}"
fi

if [ -z "$AWS_DEFAULT_REGION" ]; then
    echo "Need AWS_DEFAULT_REGION."
    exit 1
else
    echo "Using region ${AWS_DEFAULT_REGION}"
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Need AWS_ACCESS_KEY_ID."
    exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Need AWS_SECRET_ACCESS_KEY."
    exit 1
fi

if [ -z "${HASH}" ]; then
    echo "No hash given".
    exit 1
fi

bless
