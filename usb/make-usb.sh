#!/usr/bin/env bash
# make-usb.sh — Write Fedora Silverblue ISO to USB and add kickstart.
#
# Usage: usb/make-usb.sh --device /dev/sdX [--kickstart kickstart/vm-single-disk.ks]
#
# WARNING: This will ERASE ALL DATA on the target device.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse arguments
DEVICE=""
KICKSTART=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            DEVICE="${2:?--device requires a device path}"
            shift 2
            ;;
        --kickstart)
            KICKSTART="${2:?--kickstart requires a file path}"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") --device /dev/sdX [--kickstart <path>]"
            echo ""
            echo "Options:"
            echo "  --device      Target USB device (REQUIRED, e.g., /dev/sda)"
            echo "  --kickstart   Kickstart file to include on USB"
            echo ""
            echo "WARNING: This will erase ALL data on the target device."
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$DEVICE" ]]; then
    echo "ERROR: --device is required"
    echo "Usage: $(basename "$0") --device /dev/sdX"
    exit 1
fi

# Safety checks
if [[ ! -b "$DEVICE" ]]; then
    echo "ERROR: ${DEVICE} is not a block device"
    exit 1
fi

# Prevent writing to system disk
if [[ "$DEVICE" == "/dev/sda" ]] || [[ "$DEVICE" == "/dev/nvme0n1" ]]; then
    echo "WARNING: ${DEVICE} looks like a system disk!"
    echo "Are you sure? This will ERASE ALL DATA."
    read -rp "Type 'YES' to continue: " confirm
    if [[ "$confirm" != "YES" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Find ISO
ISO_PATH=""
for iso in "${REPO_DIR}"/tests/vm/Fedora-Silverblue-*.iso; do
    if [[ -f "$iso" ]]; then
        ISO_PATH="$iso"
        break
    fi
done

if [[ -z "$ISO_PATH" ]]; then
    echo "ERROR: No Fedora Silverblue ISO found."
    echo "Run: tests/vm/download-iso.sh"
    exit 1
fi

echo "=== USB Installer Creation ==="
echo "  ISO:    ${ISO_PATH}"
echo "  Device: ${DEVICE}"
if [[ -n "$KICKSTART" ]]; then
    echo "  Kickstart: ${KICKSTART}"
fi
echo ""
echo "WARNING: ALL DATA on ${DEVICE} will be ERASED!"
read -rp "Type 'YES' to continue: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# Write ISO to USB
echo ""
echo "Writing ISO to USB (this may take a while)..."

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: unmount first
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
    sudo dd if="$ISO_PATH" of="$DEVICE" bs=4m status=progress
    sync
else
    # Linux
    sudo dd if="$ISO_PATH" of="$DEVICE" bs=4M status=progress oflag=sync
fi

echo ""
echo "ISO written successfully!"

# Copy kickstart if specified
if [[ -n "$KICKSTART" ]]; then
    echo ""
    echo "To add the kickstart file, mount the USB's data partition"
    echo "and copy the kickstart files manually:"
    echo ""
    echo "  mkdir -p /mnt/usb"
    echo "  mount ${DEVICE}1 /mnt/usb  # or appropriate partition"
    echo "  cp ${KICKSTART} /mnt/usb/"
    echo "  cp -r ${REPO_DIR}/kickstart/includes/ /mnt/usb/"
    echo "  umount /mnt/usb"
    echo ""
    echo "Then patch the boot configuration:"
    echo "  usb/patch-grub.sh --device ${DEVICE}"
fi

echo ""
echo "Done! Boot from this USB to install Fedora Silverblue."
