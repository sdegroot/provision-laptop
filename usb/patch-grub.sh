#!/usr/bin/env bash
# patch-grub.sh — Patch GRUB configuration on USB to auto-load kickstart.
#
# Finds all grub.cfg files on the EFI partition and:
# 1. Adds inst.ks and rd.live.check=0 directly to any linux/linuxefi lines
# 2. Prepends set extra_cmdline= so Fedora's configfile-loaded GRUB picks it up
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

KS_PARAM="inst.ks=hd:LABEL=OEMDRV:/ks.cfg"
EXTRA_PARAMS="${KS_PARAM} rd.live.check=0"

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
trap 'sudo umount "$MOUNT_DIR" 2>/dev/null || true; rmdir "$MOUNT_DIR" 2>/dev/null || true' EXIT

echo "Mounting EFI partition ${EFI_PART}..."
if [[ "$(uname)" == "Darwin" ]]; then
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
    sudo mount -t msdos "$EFI_PART" "$MOUNT_DIR"
else
    sudo mount "$EFI_PART" "$MOUNT_DIR"
fi

# Find all grub.cfg files on the EFI partition
patched=0

while IFS= read -r -d '' grub_cfg; do
    if grep -q "$KS_PARAM" "$grub_cfg" 2>/dev/null; then
        echo "Already patched: ${grub_cfg#${MOUNT_DIR}}"
        patched=1
        continue
    fi

    echo "Patching: ${grub_cfg#${MOUNT_DIR}}"

    # Strategy 1: If there are linux/linuxefi lines, patch them directly
    if grep -qE '^\s*(linux|linuxefi)\s' "$grub_cfg" 2>/dev/null; then
        sudo sed -i.bak \
            -e "/^[[:space:]]*linux[[:space:]]/ s|\$| ${EXTRA_PARAMS}|" \
            -e "/^[[:space:]]*linuxefi[[:space:]]/ s|\$| ${EXTRA_PARAMS}|" \
            "$grub_cfg"
        sudo rm -f "${grub_cfg}.bak"
        echo "  Patched linux/linuxefi lines"
    fi

    # Strategy 2: Prepend extra_cmdline variable for Fedora's chainloaded config
    # Fedora's real grub.cfg (on the ISO9660 filesystem) appends $extra_cmdline
    # to every linux line. By setting it here before the configfile call, our
    # parameters get picked up even though the ISO is read-only.
    if grep -qE 'configfile|source' "$grub_cfg" 2>/dev/null; then
        sudo sed -i.bak \
            "1i\\
set extra_cmdline=\"${EXTRA_PARAMS}\"" \
            "$grub_cfg"
        sudo rm -f "${grub_cfg}.bak"
        echo "  Set extra_cmdline for chainloaded config"
    fi

    patched=1
done < <(sudo find "$MOUNT_DIR" -name 'grub.cfg' -print0 2>/dev/null)

if [[ $patched -eq 0 ]]; then
    echo "WARNING: No grub.cfg found on EFI partition."
    echo "Contents:"
    sudo find "$MOUNT_DIR" -type f | head -20
    echo ""
    echo "You may need to manually add to the GRUB boot line:"
    echo "  ${EXTRA_PARAMS}"
    exit 1
fi

echo ""
echo "GRUB patched. Anaconda will auto-load the kickstart on boot."
