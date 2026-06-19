#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Phosh.mobi e.V.
#
# Run a smoketest against a BengalOS VM image

set -e

TOPLEVEL=${PWD}
TMPDIR="$(mktemp -d)"
TIMEOUT=120
SLEEP=5

screenshot_vm()
{
  virsh screenshot "${NAME}" "smoke-${NAME}-boot.png" || true
}

function cleanup()
{
  # Always screenshot the VM to ease diagnosing errors
  screenshot_vm

  cd "$TOPLEVEL"
  [ -z "${TMPDIR}" ] || rm -rf "${TMPDIR}"
  [ -z "${NAME}" ] || virsh destroy "${NAME}"
}

trap cleanup EXIT

function help()
{
    cat <<EOF
Usage: $0 [-n|--name name] [-d|--disk disk]

Smoke test a VM image

  --name:    The name of the VM
  --disk:    The disk image to use
  --timeout: Timeout to wait for VM to boot
EOF
}

while [ -n "$1" ]; do
  case "$1" in
    -h|--help)
        help
        exit 0
        ;;
    -n|--name)
        shift
        NAME=$1
        ;;
    -d|--disk)
        shift
        DISK=$1
        ;;
    -t|--timeout)
        shift
        TIMEOUT=$1
        ;;
    *)
        help
        exit 1
  esac
  shift
done

function build_vm()
{
  virt-install \
        --debug \
        --connect qemu:///session \
        --name "$NAME" \
        --memory 4096 \
        --vcpus 4 \
        --os-variant debiantesting \
        --import \
        --transient \
        --noautoconsole \
        --graphics none \
        --video qxl \
        --serial pty \
        --boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=no \
        --disk "$DISK,format=qcow2" \
        --vsock cid.auto=yes
}

wait_for_vm()
{
  while [ "$TIMEOUT" -gt 0 ]; do
    if virsh qemu-agent-command "$NAME" '{"execute":"guest-ping"}'; then
      echo "✅ VM $NAME is up"
      return 0
    fi
    sleep "${SLEEP}"
    ((TIMEOUT-=SLEEP))
  done

  echo "❌ VM '$NAME' failed to boot"
}

check_vm()
{
  OS_NAME=$(virsh qemu-agent-command "$NAME" '{"execute":"guest-get-osinfo"}' | jq -r .return.name)
  OS_ID=$(virsh qemu-agent-command "$NAME" '{"execute":"guest-get-osinfo"}' | jq -r .return.id)

  if [ "${OS_NAME}" != "Phosh BengalOS" ]; then
    echo "Invalid os name '${OS_NAME}'"
    exit 1
  fi

  if [ "${OS_ID}" != "bengalos" ]; then
    echo "Invalid os id '${OS_ID}'"
    exit 1
  fi
}


build_vm
wait_for_vm
check_vm
screenshot_vm
