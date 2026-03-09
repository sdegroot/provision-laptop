#!/usr/bin/env bash
# start-vm.sh — Start the QEMU VM with port forwarding for SSH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VM configuration
VM_NAME="${VM_NAME:-silverblue-test}"
VM_DISK="${SCRIPT_DIR}/${VM_NAME}.qcow2"
VM_MEMORY="${VM_MEMORY:-4096}"
VM_CPUS="${VM_CPUS:-4}"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_EFIVARS="${SCRIPT_DIR}/${VM_NAME}-efivars.fd"

# Find EFI firmware
EFI_CODE=""
for path in \
    "/opt/homebrew/share/qemu/edk2-aarch64-code.fd" \
    "/usr/local/share/qemu/edk2-aarch64-code.fd"; do
    if [[ -f "$path" ]]; then
        EFI_CODE="$path"
        break
    fi
done

if [[ -z "$EFI_CODE" ]]; then
    echo "ERROR: Could not find edk2-aarch64-code.fd"
    exit 1
fi

if [[ ! -f "$VM_DISK" ]]; then
    echo "ERROR: VM disk not found: ${VM_DISK}"
    echo "Run: tests/vm/create-vm.sh"
    exit 1
fi

# Check for ISO (optional — only needed for first boot/install)
ISO_ARGS=()
for iso in "${SCRIPT_DIR}"/Fedora-Silverblue-ostree-aarch64-*.iso; do
    if [[ -f "$iso" ]]; then
        ISO_ARGS=(-drive "file=${iso},format=raw,if=none,id=cd0,media=cdrom,readonly=on" -device usb-storage,drive=cd0)
        echo "Booting with ISO: ${iso}"
        break
    fi
done

# PID file
PID_DIR="${SCRIPT_DIR}/pid"
mkdir -p "$PID_DIR"
PID_FILE="${PID_DIR}/${VM_NAME}.pid"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "VM is already running (PID: $(cat "$PID_FILE"))"
    exit 1
fi

echo "Starting VM: ${VM_NAME}"
echo "  Memory:   ${VM_MEMORY}MB"
echo "  CPUs:     ${VM_CPUS}"
echo "  SSH port: localhost:${VM_SSH_PORT} -> VM:22"
echo ""

# Build QEMU command
QEMU_ARGS=(
    -name "$VM_NAME"
    -machine virt,accel=hvf,highmem=on
    -cpu host
    -m "$VM_MEMORY"
    -smp "$VM_CPUS"
    -drive "if=pflash,format=raw,file=${EFI_CODE},readonly=on"
    -drive "if=pflash,format=raw,file=${VM_EFIVARS}"
    -drive "file=${VM_DISK},format=qcow2,if=none,id=hd0"
    -device virtio-blk-pci,drive=hd0
    -device virtio-net-pci,netdev=net0
    -netdev "user,id=net0,hostfwd=tcp::${VM_SSH_PORT}-:22"
    -device qemu-xhci
    -device usb-kbd
    -device usb-tablet
    ${ISO_ARGS[@]+"${ISO_ARGS[@]}"}
    -pidfile "$PID_FILE"
)

# Use cocoa display on macOS for GUI (needed for Anaconda installer)
# Pass --nographic to skip the GUI and run headless
if [[ "${VM_NOGRAPHIC:-}" == "1" ]]; then
    QEMU_ARGS+=(-display none)
    QEMU_ARGS+=(-daemonize)
else
    QEMU_ARGS+=(-device ramfb)
    QEMU_ARGS+=(-display cocoa)
fi

qemu-system-aarch64 "${QEMU_ARGS[@]}" \
    || { echo "Failed to start VM"; exit 1; }

if [[ "${VM_NOGRAPHIC:-}" == "1" ]]; then
    echo "VM started in background! PID: $(cat "$PID_FILE")"
else
    echo "VM window closed."
fi
echo ""
echo "Connect via SSH: tests/vm/ssh-vm.sh"
