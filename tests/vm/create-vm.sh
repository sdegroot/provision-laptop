#!/usr/bin/env bash
# create-vm.sh — Create a QEMU VM with EFI boot for Fedora Silverblue.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VM configuration
VM_NAME="${VM_NAME:-silverblue-test}"
VM_DISK="${SCRIPT_DIR}/${VM_NAME}.qcow2"
VM_DISK_SIZE="${VM_DISK_SIZE:-60G}"
VM_MEMORY="${VM_MEMORY:-4096}"
VM_CPUS="${VM_CPUS:-4}"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"

# Find EFI firmware from Homebrew's QEMU package
EFI_CODE=""
for path in \
    "/opt/homebrew/share/qemu/edk2-aarch64-code.fd" \
    "/usr/local/share/qemu/edk2-aarch64-code.fd" \
    "/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-aarch64-code.fd"; do
    # shellcheck disable=SC2086
    for resolved in $path; do
        if [[ -f "$resolved" ]]; then
            EFI_CODE="$resolved"
            break 2
        fi
    done
done

if [[ -z "$EFI_CODE" ]]; then
    echo "ERROR: Could not find edk2-aarch64-code.fd"
    echo "Install QEMU: brew install qemu"
    exit 1
fi

# Find ISO
ISO_PATH=""
for iso in "${SCRIPT_DIR}"/Fedora-Silverblue-ostree-aarch64-*.iso; do
    if [[ -f "$iso" ]]; then
        ISO_PATH="$iso"
        break
    fi
done

if [[ -z "$ISO_PATH" ]]; then
    echo "ERROR: No Fedora Silverblue ISO found in ${SCRIPT_DIR}"
    echo "Run: tests/vm/download-iso.sh"
    exit 1
fi

# Create disk image
if [[ -f "$VM_DISK" ]]; then
    echo "Disk image already exists: ${VM_DISK}"
    echo "Run tests/vm/destroy-vm.sh first to recreate."
    exit 1
fi

echo "Creating VM disk: ${VM_DISK} (${VM_DISK_SIZE})"
qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"

# Copy EFI vars (writable copy)
VM_EFIVARS="${SCRIPT_DIR}/${VM_NAME}-efivars.fd"
cp "$EFI_CODE" "$VM_EFIVARS"

echo ""
echo "VM created successfully!"
echo "  Disk:     ${VM_DISK}"
echo "  EFI vars: ${VM_EFIVARS}"
echo "  ISO:      ${ISO_PATH}"
echo ""
echo "Start the VM with: tests/vm/start-vm.sh"
