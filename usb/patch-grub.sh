#!/usr/bin/env bash
# patch-grub.sh — Patch GRUB configuration on USB to auto-load kickstart.
#
# Usage: usb/patch-grub.sh --device /dev/sdX

set -euo pipefail

DEVICE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            DEVICE="${2:?--device requires a device path}"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") --device /dev/sdX"
            echo ""
            echo "Patches the GRUB configuration on a Fedora USB installer"
            echo "to automatically use the kickstart file on the USB."
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
    exit 1
fi

echo "=== GRUB Patcher ==="
echo ""
echo "This script patches the GRUB configuration on the USB installer"
echo "to add 'inst.ks=hd:LABEL=OEMDRV:/ks.cfg' to the boot parameters."
echo ""
echo "Steps to complete manually:"
echo ""
echo "1. Mount the EFI partition of the USB:"
echo "   mkdir -p /mnt/usb-efi"
echo "   mount ${DEVICE}2 /mnt/usb-efi  # EFI partition (adjust number)"
echo ""
echo "2. Edit the GRUB config:"
echo "   vi /mnt/usb-efi/EFI/BOOT/grub.cfg"
echo ""
echo "3. Find the 'Install Fedora' menu entry and add to the linux line:"
echo "   inst.ks=hd:LABEL=OEMDRV:/ks.cfg"
echo ""
echo "4. Unmount:"
echo "   umount /mnt/usb-efi"
echo ""
echo "Alternative: Create a second partition labeled 'OEMDRV' with the"
echo "kickstart file named 'ks.cfg' — Anaconda will auto-detect it."
