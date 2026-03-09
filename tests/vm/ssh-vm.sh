#!/usr/bin/env bash
# ssh-vm.sh — SSH into the running VM.
set -euo pipefail

VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_USER="${VM_USER:-sdegroot}"
VM_PASSWORD="${VM_PASSWORD:-changeme}"

SSH_OPTS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR
    -o IdentityAgent=none
    -o IdentitiesOnly=yes
    -p "$VM_SSH_PORT"
)

if command -v sshpass &>/dev/null; then
    exec sshpass -p "$VM_PASSWORD" ssh "${SSH_OPTS[@]}" "${VM_USER}@localhost" "$@"
else
    exec ssh "${SSH_OPTS[@]}" "${VM_USER}@localhost" "$@"
fi
