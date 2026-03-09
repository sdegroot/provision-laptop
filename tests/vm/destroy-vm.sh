#!/usr/bin/env bash
# destroy-vm.sh — Stop and destroy the VM and its disk image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VM_NAME="${VM_NAME:-silverblue-test}"
VM_DISK="${SCRIPT_DIR}/${VM_NAME}.qcow2"
VM_EFIVARS="${SCRIPT_DIR}/${VM_NAME}-efivars.fd"
PID_FILE="${SCRIPT_DIR}/pid/${VM_NAME}.pid"

# Stop VM if running
if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping VM (PID: ${pid})..."
        kill "$pid"
        # Wait for process to exit
        for i in $(seq 1 10); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 1
        done
        if kill -0 "$pid" 2>/dev/null; then
            echo "Force killing VM..."
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
    rm -f "$PID_FILE"
fi

# Remove disk and EFI vars
removed=0
for f in "$VM_DISK" "$VM_EFIVARS"; do
    if [[ -f "$f" ]]; then
        echo "Removing: ${f}"
        rm -f "$f"
        removed=1
    fi
done

if [[ $removed -eq 0 ]]; then
    echo "No VM artifacts found for: ${VM_NAME}"
else
    echo "VM destroyed: ${VM_NAME}"
fi
