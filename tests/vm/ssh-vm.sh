#!/usr/bin/env bash
# ssh-vm.sh — SSH into the running VM.
set -euo pipefail

VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_USER="${VM_USER:-admin}"

exec ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -p "$VM_SSH_PORT" \
    "${VM_USER}@localhost" \
    "$@"
