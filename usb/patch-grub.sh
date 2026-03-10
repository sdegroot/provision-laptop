#!/usr/bin/env bash
# patch-grub.sh — Patch GRUB configuration on USB to auto-load kickstart.
#
# Finds all grub.cfg files on the EFI partition and:
# 1. Adds kernel params directly to any linux/linuxefi lines
# 2. Prepends set extra_cmdline= so Fedora's chainloaded GRUB picks them up
# 3. Fixes stale inst.stage2=hd:LABEL= references in writable EFI grub.cfg files
#
# The chainloaded grub.cfg (on the read-only ISO9660 filesystem) may have a
# stale inst.stage2 label. extra_cmdline appends AFTER it so our value wins.
#
# inst.ks=hd:LABEL=OEMDRV:/ks.cfg is included alongside Anaconda's OEMDRV
# auto-detection as belt-and-suspenders. ks.cfg is also copied to the EFI
# partition as an additional fallback.
#
# Usage: usb/patch-grub.sh --device /dev/sdX [--iso-label LABEL]

set -euo pipefail

DEVICE=""
EFI_PART_NUM="${EFI_PART_NUM:-2}"
ISO_LABEL=""
KS_FILE=""

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
        --iso-label)
            ISO_LABEL="${2:?--iso-label requires a volume label}"
            shift 2
            ;;
        --ks-file)
            KS_FILE="${2:?--ks-file requires a path to ks.cfg}"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") --device /dev/sdX [--efi-part N] [--iso-label LABEL] [--ks-file PATH]"
            echo ""
            echo "Patches GRUB on a Fedora USB installer to auto-load the"
            echo "kickstart from the OEMDRV partition."
            echo ""
            echo "Options:"
            echo "  --device /dev/sdX   USB device"
            echo "  --efi-part N        EFI partition number (default: 2)"
            echo "  --iso-label LABEL   ISO volume label (for fixing inst.stage2)"
            echo "  --ks-file PATH      Copy kickstart to EFI partition (fallback)"
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

# Build kernel params to inject:
# - rd.live.check=0: skip ISO checksum (always fails on USB)
# - inst.stage2: override the stale label from the read-only ISO grub.cfg
# - inst.ks: explicitly load kickstart from OEMDRV (belt-and-suspenders with
#   Anaconda's own OEMDRV auto-detection, which may not work on all hardware)
ALREADY_PATCHED_MARKER="rd.live.check=0"
KS_PARAM="inst.ks=hd:LABEL=OEMDRV:/ks.cfg"
if [[ -n "$ISO_LABEL" ]]; then
    EXTRA_PARAMS="rd.live.check=0 inst.stage2=hd:LABEL=${ISO_LABEL} ${KS_PARAM}"
else
    EXTRA_PARAMS="rd.live.check=0 ${KS_PARAM}"
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
    if grep -q "$ALREADY_PATCHED_MARKER" "$grub_cfg" 2>/dev/null; then
        echo "Already patched: ${grub_cfg#${MOUNT_DIR}}"
        patched=1
        continue
    fi

    echo "Patching: ${grub_cfg#${MOUNT_DIR}}"

    # Strategy 1: If there are linux/linuxefi lines in this EFI grub.cfg,
    # append params directly. Also replace any stale inst.stage2 label.
    if grep -qE '^\s*(linux|linuxefi)\s' "$grub_cfg" 2>/dev/null; then
        sudo sed -i.bak \
            -e "/^[[:space:]]*linux[[:space:]]/ s|\$| ${EXTRA_PARAMS}|" \
            -e "/^[[:space:]]*linuxefi[[:space:]]/ s|\$| ${EXTRA_PARAMS}|" \
            "$grub_cfg"
        sudo rm -f "${grub_cfg}.bak"
        echo "  Patched linux/linuxefi lines"
        # Also fix stale inst.stage2 in-place (belt-and-suspenders)
        if [[ -n "$ISO_LABEL" ]] && grep -qE 'inst\.stage2=hd:LABEL=' "$grub_cfg" 2>/dev/null; then
            sudo sed -i.bak \
                "s|inst\.stage2=hd:LABEL=[^ ]*|inst.stage2=hd:LABEL=${ISO_LABEL}|g" \
                "$grub_cfg"
            sudo rm -f "${grub_cfg}.bak"
            echo "  Fixed inst.stage2 label -> ${ISO_LABEL}"
        fi
    fi

    # Strategy 2: Prepend extra_cmdline variable for Fedora's chainloaded config.
    # Fedora's real grub.cfg (on the read-only ISO9660 filesystem) appends
    # $extra_cmdline to every linuxefi line. Setting it here before the configfile
    # call injects our params — including the inst.stage2 override which overrides
    # the stale label baked into the ISO's grub.cfg (last value wins on cmdline).
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

# Copy kickstart to EFI partition as an additional fallback.
# Anaconda's OEMDRV auto-detection is the primary mechanism, but having ks.cfg
# on the EFI partition too means it can be referenced if OEMDRV fails.
if [[ -n "$KS_FILE" && -f "$KS_FILE" ]]; then
    sudo cp "$KS_FILE" "${MOUNT_DIR}/ks.cfg"
    echo "Copied ks.cfg to EFI partition"
fi

echo ""
echo "GRUB patched. Anaconda will auto-detect kickstart from OEMDRV partition."
