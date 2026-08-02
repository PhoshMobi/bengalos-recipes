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

check_vm_osinfo()
{
  local os_name os_id

  os_name=$(virsh qemu-agent-command "$NAME" '{"execute":"guest-get-osinfo"}' | jq -r .return.name)
  os_id=$(virsh qemu-agent-command "$NAME" '{"execute":"guest-get-osinfo"}' | jq -r .return.id)

  if [ "${os_name}" != "Phosh BengalOS" ]; then
    echo "Invalid os name '${os_name}'"
    exit 1
  fi

  if [ "${os_id}" != "bengalos" ]; then
    echo "Invalid os id '${os_id}'"
    exit 1
  fi
}


check_vm_greetd()
{
  local pid deadline status

  pid=$(
    virsh qemu-agent-command "$NAME" \
    '{
      "execute":"guest-exec",
      "arguments":{
        "path":"/bin/sh",
        "arg":["-c","timeout 30 sh -c '\''until systemctl is-active --quiet greetd.service; do sleep 1; done'\''"]
      }
    }' | jq -r '.return.pid'
  )

  echo "Got pid: $pid"
  deadline=$(( $(date +%s) + 35 ))
  while (( $(date +%s) < deadline )); do
    status=$(
        virsh qemu-agent-command "$NAME" \
        '{"execute": "guest-exec-status", "arguments": { "pid": '"$pid"' }}'
    )

    ret="$(jq -r '.return.exitcode // empty' <<<"$status")"
    if [ "$ret" = "0" ]; then
      echo "Greetd is active"
      return 0
    elif [ -n "$ret" ]; then
      echo "Greetd not active"
      return 1
    fi

    sleep 0.2
  done

  echo "Checking for greetd timed out"
  return 1
}


build_vm
wait_for_vm
check_vm_osinfo
check_vm_greetd
screenshot_vm
