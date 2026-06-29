#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Phosh.mobi e.V.
#
# Bless BengalOS images and publish them

set -e
set -o pipefail

TOPLEVEL=${PWD}
STAGING_BUCKET=bengalos-staging
STAGING_PREFIX=staging
BLESSED_BUCKET=bengalos-images
DRY_RUN=0
TMPDIR="$(mktemp -d)"
SIGNING_KEY="${BENGALOS_SIGNING_KEY}"

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
Usage: $0 [--dry-run] [-h|--hash hash]

Bless an immutable image

  --hash:    The hash of the to be blessed images's checksum file
  --dry-run: Don't bless anything, just print what would be blessed
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
    --dry-run)
        DRY_RUN=1
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

  for file in "${sha256sums}" "${sha256sums}.gpg"; do
      aws s3 cp \
          "s3://${STAGING_BUCKET}/${STAGING_PREFIX}/${HASH}/${file}" \
          "${TMPDIR}/${file}" \
          --only-show-errors
  done

  echo "🔐 Verifying checksum file integrity…"
  { # Verify checksum file of to be blessed images
    cd "${TMPDIR}"
    if ! sha256sum -c hash; then
      echo "Checksum of ${sha256sums} invalid"
      exit 1
    fi

    if ! gpg --verify "${sha256sums}.gpg" "${sha256sums}"; then
      echo "🚨 Failed to verify signature on staging checksum file ${sha256sums}"
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
      echo "No VARIANT_ID in osrelease"
      exit 1
  fi

  if [ -z "${VERSION_CODENAME}" ]; then
      echo "No VERSION_CODENAME in osrelease"
      exit 1
  fi

  # Get architecture
  manifest=$(awk '/.manifest/ { print $2 }' "${TMPDIR}/${sha256sums}")
  aws s3 cp \
      "s3://${STAGING_BUCKET}/${STAGING_PREFIX}/${HASH}/${manifest}" \
      "${TMPDIR}/${manifest}" \
      --only-show-errors
  ARCH=$(jq -r  '.config | .architecture' "${TMPDIR}/${manifest}")

  if [ -z "${ARCH}" ]; then
      echo "No ARCH in manifest"
      exit 1
  fi

  blessed_prefix="${VERSION_CODENAME}/${ARCH}/${VARIANT_ID}"

  if [ $DRY_RUN -ne 0 ]; then
      echo "Would bless ${HASH} to ${blessed_prefix}"
      return
  fi

  echo "📦 Publishing artifacts to blessed bucket…"

  # Copy each artifact listed in the checksum file
  awk '{ print $2 }' "${TMPDIR}/${sha256sums}" | while IFS= read -r file; do
      echo "  → ${file}"

      aws s3 cp \
          "s3://${STAGING_BUCKET}/${STAGING_PREFIX}/${HASH}/${file}" \
          "s3://${BLESSED_BUCKET}/${blessed_prefix}/${file}" \
          --only-show-errors
  done

  echo "📄 Updating global SHA256SUMS index…"
  # Fetch existing index
  for file in SHA256SUMS SHA256SUMS.gpg; do
      aws s3 cp \
          "s3://${BLESSED_BUCKET}/${blessed_prefix}/${file}" \
          "${TMPDIR}/${file}" \
          --only-show-errors \
          || touch "${TMPDIR}/${file}"
  done

  { # Verify checksum file of currently blessed images
    cd "${TMPDIR}"
    if [ ! -s SHA256SUMS ]; then
      echo "⚠️ Not checking signature on empty checksum file."
    elif ! gpg --verify SHA256SUMS.gpg SHA256SUMS; then
      echo "🚨 Failed to verify signature on checksum file"
      exit 1
    fi
  }

  { # Add new checksums and resign
    cd "${TMPDIR}"
    cat SHA256SUMS "${sha256sums}" | sort -k2,2 | uniq >> SHA256SUMS.tmp
    mv SHA256SUMS.tmp SHA256SUMS
    rm SHA256SUMS.gpg
    gpg --sign --default-key="${SIGNING_KEY}" --detach-sign --armor -o SHA256SUMS.gpg SHA256SUMS
  }

  # Upload updated index
  for file in SHA256SUMS SHA256SUMS.gpg; do
      aws s3 cp \
          "${TMPDIR}/${file}" \
          "s3://${BLESSED_BUCKET}/${blessed_prefix}/${file}" \
          --only-show-errors
  done

  # TODO: Current systemd looks at SHA256SUMS.sha256.asc. Recheck with
  # 261 and file issue if still present
  aws s3 cp "s3://${BLESSED_BUCKET}/${blessed_prefix}/SHA256SUMS.gpg" \
      "s3://${BLESSED_BUCKET}/${blessed_prefix}/SHA256SUMS.sha256.asc"

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
