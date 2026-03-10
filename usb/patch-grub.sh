#!/usr/bin/env bash
# patch-grub.sh — Patch GRUB configuration on USB to auto-load kickstart.
#
# Mounts the EFI partition of the USB installer and adds
# inst.ks=hd:LABEL=OEMDRV:/ks.cfg to every GRUB menu entry's
# kernel command line.
#
# Usage: usb/patch-grub.sh --device /dev/sdX

set -euo pipefail

DEVICE=""
EFI_PART_NUM="${EFI_PART_NUM:-2}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            DEVICE="${2:?--device requires a device path}"
            shift 2
            ;;
        --efi-part)
            EFI_PART_NUM="${2:?--efi-part requires a partition number}"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") --device /dev/sdX [--efi-part N]"
            echo ""
            echo "Patches GRUB on a Fedora USB installer to auto-load the"
            echo "kickstart from the OEMDRV partition."
            echo ""
            echo "Options:"
            echo "  --device /dev/sdX   USB device"
            echo "  --efi-part N        EFI partition number (default: 2)"
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

# Determine the EFI partition device path
DISK_BASE="$(basename "$DEVICE")"
if [[ "$(uname)" == "Darwin" ]]; then
    EFI_PART="/dev/${DISK_BASE}s${EFI_PART_NUM}"
else
    if [[ "$DEVICE" =~ [0-9]$ ]]; then
        EFI_PART="${DEVICE}p${EFI_PART_NUM}"
    else
        EFI_PART="${DEVICE}${EFI_PART_NUM}"
    fi
fi

if [[ ! -e "$EFI_PART" ]]; then
    echo "ERROR: EFI partition not found at ${EFI_PART}"
    echo "Check 'diskutil list ${DEVICE}' (macOS) or 'lsblk ${DEVICE}' (Linux)"
    echo "and use --efi-part N to specify the correct partition number."
    exit 1
fi

# Mount the EFI partition
MOUNT_DIR="$(mktemp -d)"
trap 'sudo umount "$MOUNT_DIR" 2>/dev/null; rmdir "$MOUNT_DIR" 2>/dev/null' EXIT

echo "Mounting EFI partition ${EFI_PART}..."
if [[ "$(uname)" == "Darwin" ]]; then
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
    sudo mount -t msdos "$EFI_PART" "$MOUNT_DIR"
else
    sudo mount "$EFI_PART" "$MOUNT_DIR"
fi

# Find GRUB config
KS_PARAM="inst.ks=hd:LABEL=OEMDRV:/ks.cfg"
patched=0

for grub_cfg in \
    "${MOUNT_DIR}/EFI/BOOT/grub.cfg" \
    "${MOUNT_DIR}/EFI/fedora/grub.cfg" \
    "${MOUNT_DIR}/boot/grub2/grub.cfg"; do

    if [[ ! -f "$grub_cfg" ]]; then
        continue
    fi

    if grep -q "$KS_PARAM" "$grub_cfg"; then
        echo "Already patched: ${grub_cfg}"
        patched=1
        continue
    fi

    echo "Patching: ${grub_cfg}"

    # Add inst.ks= to every linux/linuxefi line that doesn't already have it
    sudo sed -i.bak \
        "/^[[:space:]]*\(linux\|linuxefi\)[[:space:]]/ {
            /${KS_PARAM//\//\\/}/! s|\$| ${KS_PARAM}|
        }" "$grub_cfg"

    sudo rm -f "${grub_cfg}.bak"
    patched=1
    echo "  Added ${KS_PARAM} to kernel boot lines"
done

if [[ $patched -eq 0 ]]; then
    echo "WARNING: No GRUB config found to patch."
    echo "Looked in EFI/BOOT/grub.cfg, EFI/fedora/grub.cfg, boot/grub2/grub.cfg"
    exit 1
fi

echo ""
echo "GRUB patched. Anaconda will auto-load the kickstart on boot."
