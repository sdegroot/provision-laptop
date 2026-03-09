#!/usr/bin/env bash
# make-usb.sh — Create a bootable USB installer for Fedora Silverblue.
#
# Creates a USB drive with:
#   1. Fedora Silverblue ISO written directly to the drive
#   2. An additional OEMDRV partition containing:
#      - Flattened kickstart (ks.cfg) — auto-detected by Anaconda
#      - Bundled provision-laptop repo — copied to /home during install
#
# Usage: usb/make-usb.sh --device /dev/sdX
#
# WARNING: This will ERASE ALL DATA on the target device.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse arguments
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
            echo "Creates a bootable Fedora Silverblue USB installer with"
            echo "kickstart and bundled provisioning repo."
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

# Prevent writing to likely system disks
for sys_disk in "/dev/sda" "/dev/nvme0n1" "/dev/nvme1n1"; do
    if [[ "$DEVICE" == "$sys_disk" ]]; then
        echo "ERROR: ${DEVICE} looks like a system disk. Refusing."
        echo "If this is really a USB drive, check 'lsblk' and use the correct device."
        exit 1
    fi
done

# Find ISO
ISO_PATH=""
for iso in "${REPO_DIR}"/tests/vm/Fedora-Silverblue-*.iso; do
    if [[ -f "$iso" ]]; then
        ISO_PATH="$iso"
        break
    fi
done

if [[ -z "$ISO_PATH" ]]; then
    # Also check .bak
    for iso in "${REPO_DIR}"/tests/vm/Fedora-Silverblue-*.iso.bak; do
        if [[ -f "$iso" ]]; then
            ISO_PATH="$iso"
            break
        fi
    done
fi

if [[ -z "$ISO_PATH" ]]; then
    echo "ERROR: No Fedora Silverblue ISO found."
    echo "Run: tests/vm/download-iso.sh"
    exit 1
fi

# -------------------------------------------------------------------------
# Flatten kickstart
# -------------------------------------------------------------------------

flatten_kickstart() {
    local ks_file="$1"
    local ks_dir
    ks_dir="$(dirname "$ks_file")"

    while IFS= read -r line; do
        if [[ "$line" =~ ^%include[[:space:]]+(.+)$ ]]; then
            local include_path="${BASH_REMATCH[1]}"
            local resolved="${ks_dir}/${include_path}"
            if [[ -f "$resolved" ]]; then
                echo "# --- included from: ${include_path} ---"
                flatten_kickstart "$resolved"
                echo "# --- end include: ${include_path} ---"
            else
                echo "ERROR: Cannot find include: ${resolved}" >&2
                exit 1
            fi
        else
            echo "$line"
        fi
    done < "$ks_file"
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Flattening kickstart..."
flatten_kickstart "${REPO_DIR}/kickstart/laptop-dual-disk.ks" > "${WORK_DIR}/ks.cfg"

# -------------------------------------------------------------------------
# Bundle repo (git archive for clean copy without .git internals)
# -------------------------------------------------------------------------

echo "Bundling provisioning repo..."
BUNDLE_DIR="${WORK_DIR}/provision-laptop"
mkdir -p "$BUNDLE_DIR"

if command -v git &>/dev/null && [[ -d "${REPO_DIR}/.git" ]]; then
    # Use git archive for a clean export (respects .gitignore, no .git dir)
    git -C "$REPO_DIR" archive HEAD | tar -x -C "$BUNDLE_DIR"
else
    # Fallback: copy everything except .git and VM artifacts
    rsync -a --exclude='.git' --exclude='tests/vm/*.iso*' \
        --exclude='tests/vm/*.qcow2' --exclude='tests/vm/*.fd' \
        --exclude='tests/vm/pid' --exclude='tests/vm/.ks-work' \
        "$REPO_DIR/" "$BUNDLE_DIR/"
fi

# -------------------------------------------------------------------------
# Confirm with user
# -------------------------------------------------------------------------

ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)

echo ""
echo "=== USB Installer Creation ==="
echo "  ISO:      ${ISO_PATH} (${ISO_SIZE})"
echo "  Device:   ${DEVICE}"
echo "  Kickstart: laptop-dual-disk.ks (flattened)"
echo "  Repo:     bundled ($(find "$BUNDLE_DIR" -type f | wc -l | tr -d ' ') files)"
echo ""
echo "This will:"
echo "  1. Write the Fedora Silverblue ISO to ${DEVICE}"
echo "  2. Create an OEMDRV partition with kickstart + repo"
echo ""
echo "WARNING: ALL DATA on ${DEVICE} will be ERASED!"
read -rp "Type 'YES' to continue: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# -------------------------------------------------------------------------
# Step 1: Write ISO to USB
# -------------------------------------------------------------------------

echo ""
echo "Step 1/3: Writing ISO to USB (this may take a while)..."

if [[ "$(uname)" == "Darwin" ]]; then
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
    sudo dd if="$ISO_PATH" of="$DEVICE" bs=4m status=progress
    sync
else
    sudo umount "${DEVICE}"* 2>/dev/null || true
    sudo dd if="$ISO_PATH" of="$DEVICE" bs=4M status=progress oflag=sync
fi

echo "ISO written."

# -------------------------------------------------------------------------
# Step 2: Create OEMDRV partition in remaining space
# -------------------------------------------------------------------------

echo ""
echo "Step 2/3: Creating OEMDRV partition..."

# Get ISO size in bytes and calculate start sector for new partition
ISO_BYTES=$(stat -f%z "$ISO_PATH" 2>/dev/null || stat -c%s "$ISO_PATH")
ISO_SECTORS=$(( (ISO_BYTES + 511) / 512 ))
# Leave a 2048-sector gap after ISO
OEMDRV_START=$(( ISO_SECTORS + 2048 ))

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: use diskutil to add a partition
    # First, re-read partition table
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true

    echo "Creating OEMDRV partition starting at sector ${OEMDRV_START}..."
    # Use gdisk/sgdisk if available, otherwise guide manual steps
    if command -v sgdisk &>/dev/null; then
        # Create a new GPT partition after the ISO data
        sudo sgdisk \
            --new=0:${OEMDRV_START}:0 \
            --typecode=0:0700 \
            --change-name=0:OEMDRV \
            "$DEVICE"

        # Format the new partition as FAT32
        diskutil unmountDisk "$DEVICE" 2>/dev/null || true
        sleep 2

        # Find the new partition (usually last one)
        OEMDRV_PART="${DEVICE}s$(diskutil list "$DEVICE" | grep -c 'disk.*s[0-9]')" || true
        # Try common partition names
        for part in "${DEVICE}s3" "${DEVICE}s4" "${DEVICE}s2"; do
            if [[ -e "$part" ]]; then
                OEMDRV_PART="$part"
                break
            fi
        done

        if [[ -b "$OEMDRV_PART" ]]; then
            sudo newfs_msdos -F 32 -v OEMDRV "$OEMDRV_PART"
        else
            echo "WARNING: Could not find new partition to format"
            echo "You may need to format it manually as FAT32 with label OEMDRV"
        fi
    else
        echo "ERROR: sgdisk not found. Install: brew install gptfdisk"
        exit 1
    fi
else
    # Linux: use sgdisk + mkfs.vfat
    sudo sgdisk \
        --new=0:${OEMDRV_START}:0 \
        --typecode=0:0700 \
        --change-name=0:OEMDRV \
        "$DEVICE"
    sudo partprobe "$DEVICE"
    sleep 2

    # Find the new partition
    OEMDRV_PART="$(lsblk -lnp -o NAME "$DEVICE" | tail -1)"
    sudo mkfs.vfat -F 32 -n OEMDRV "$OEMDRV_PART"
fi

# -------------------------------------------------------------------------
# Step 3: Copy kickstart + repo to OEMDRV
# -------------------------------------------------------------------------

echo ""
echo "Step 3/3: Copying kickstart and repo to OEMDRV..."

OEMDRV_MOUNT="${WORK_DIR}/oemdrv-mount"
mkdir -p "$OEMDRV_MOUNT"

if [[ "$(uname)" == "Darwin" ]]; then
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
    sleep 1
    sudo mount -t msdos "$OEMDRV_PART" "$OEMDRV_MOUNT"
else
    sudo mount "$OEMDRV_PART" "$OEMDRV_MOUNT"
fi

sudo cp "${WORK_DIR}/ks.cfg" "${OEMDRV_MOUNT}/ks.cfg"
sudo cp -r "$BUNDLE_DIR" "${OEMDRV_MOUNT}/provision-laptop"

if [[ "$(uname)" == "Darwin" ]]; then
    sudo umount "$OEMDRV_MOUNT"
    diskutil eject "$DEVICE" 2>/dev/null || true
else
    sudo umount "$OEMDRV_MOUNT"
    sudo eject "$DEVICE" 2>/dev/null || true
fi

echo ""
echo "=== USB installer created successfully! ==="
echo ""
echo "Boot from this USB to install Fedora Silverblue."
echo "Anaconda will auto-detect the kickstart from the OEMDRV partition."
echo ""
echo "After install & first boot:"
echo "  1. Enroll YubiKey for LUKS unlock"
echo "  2. Install & configure 1Password"
echo "  3. cd ~/provision-laptop && git pull && bin/apply"
