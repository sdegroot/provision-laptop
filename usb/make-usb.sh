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

# Find x86_64 ISO (the laptop kickstart targets x86_64)
ISO_PATH=""
for iso in "${REPO_DIR}"/tests/vm/Fedora-Silverblue-*x86_64*.iso \
           "${REPO_DIR}"/tests/vm/Fedora-Silverblue-*x86_64*.iso.bak; do
    if [[ -f "$iso" ]]; then
        ISO_PATH="$iso"
        break
    fi
done

if [[ -z "$ISO_PATH" ]]; then
    echo "ERROR: No x86_64 Fedora Silverblue ISO found."
    echo ""
    # Check if an aarch64 ISO exists and warn
    for iso in "${REPO_DIR}"/tests/vm/Fedora-Silverblue-*aarch64*; do
        if [[ -f "$iso" ]]; then
            echo "Found aarch64 ISO ($(basename "$iso")) but the laptop needs x86_64."
            break
        fi
    done
    echo "Download it with:"
    echo "  tests/vm/download-iso.sh --arch x86_64"
    exit 1
fi

# Verify the ISO is x86_64 (guard against misnamed files)
ISO_BASENAME="$(basename "$ISO_PATH")"
if [[ "$ISO_BASENAME" == *"aarch64"* ]]; then
    echo "ERROR: ${ISO_BASENAME} is an aarch64 ISO."
    echo "The laptop kickstart targets x86_64. Download the x86_64 ISO."
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
# Step 1.5: Patch GRUB to auto-load kickstart
# -------------------------------------------------------------------------

echo ""
echo "Patching GRUB to auto-load kickstart from OEMDRV..."
"${SCRIPT_DIR}/patch-grub.sh" --device "$DEVICE"

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

if ! command -v sgdisk &>/dev/null; then
    echo "ERROR: sgdisk not found."
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "Install: brew install gptfdisk"
    else
        echo "Install: sudo dnf install gdisk  (or apt install gdisk)"
    fi
    exit 1
fi

# After dd'ing the ISO, the GPT backup header still reflects the ISO's
# original size, not the USB drive's actual size. Move it to the real end
# of the disk so sgdisk can use the remaining space.
echo "Relocating GPT backup header to end of disk..."
sudo sgdisk --move-second-header "$DEVICE"

# Snapshot partition count before adding the new one
if [[ "$(uname)" == "Darwin" ]]; then
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
fi

echo "Creating OEMDRV partition starting at sector ${OEMDRV_START}..."
sudo sgdisk \
    --new=0:${OEMDRV_START}:0 \
    --typecode=0:0700 \
    --change-name=0:OEMDRV \
    "$DEVICE"

# Find the new OEMDRV partition by its GPT label
DISK_BASE="$(basename "$DEVICE")"

if [[ "$(uname)" == "Darwin" ]]; then
    diskutil unmountDisk "$DEVICE" 2>/dev/null || true
    sleep 2

    # Parse the new partition number: find the highest-numbered partition
    # from sgdisk --print (the one we just created).
    NEW_PART_NUM="$(sudo sgdisk --print "$DEVICE" 2>/dev/null \
        | grep '^ *[0-9]' | awk '{print $1}' | sort -n | tail -1)"

    if [[ -z "$NEW_PART_NUM" ]]; then
        echo "ERROR: Could not determine new partition number from sgdisk."
        echo "Check 'diskutil list ${DEVICE}' and format the last partition manually:"
        echo "  sudo newfs_msdos -F 32 -v OEMDRV /dev/${DISK_BASE}sN"
        exit 1
    fi

    OEMDRV_PART="/dev/${DISK_BASE}s${NEW_PART_NUM}"

    # Wait for the partition to appear (macOS can be slow to re-read)
    for attempt in 1 2 3 4 5; do
        if [[ -e "$OEMDRV_PART" ]]; then
            break
        fi
        diskutil unmountDisk "$DEVICE" 2>/dev/null || true
        sleep 2
    done

    if [[ ! -e "$OEMDRV_PART" ]]; then
        echo "ERROR: New partition ${OEMDRV_PART} did not appear."
        echo "Check 'diskutil list ${DEVICE}' and format the last partition manually:"
        echo "  sudo newfs_msdos -F 32 -v OEMDRV /dev/${DISK_BASE}sN"
        exit 1
    fi

    echo "Formatting ${OEMDRV_PART} as FAT32..."
    sudo newfs_msdos -F 32 -v OEMDRV "$OEMDRV_PART"
else
    sudo partprobe "$DEVICE"
    sleep 2

    # Find the new partition: highest-numbered partition from sgdisk
    NEW_PART_NUM="$(sudo sgdisk --print "$DEVICE" 2>/dev/null \
        | grep '^ *[0-9]' | awk '{print $1}' | sort -n | tail -1)"

    if [[ -z "$NEW_PART_NUM" ]]; then
        echo "ERROR: Could not determine new partition number from sgdisk."
        echo "Check 'lsblk ${DEVICE}' and format the last partition manually:"
        echo "  sudo mkfs.vfat -F 32 -n OEMDRV ${DEVICE}N"
        exit 1
    fi

    # Linux partition naming: /dev/sdb4 or /dev/nvme0n1p4
    if [[ "$DEVICE" =~ [0-9]$ ]]; then
        OEMDRV_PART="${DEVICE}p${NEW_PART_NUM}"
    else
        OEMDRV_PART="${DEVICE}${NEW_PART_NUM}"
    fi

    echo "Formatting ${OEMDRV_PART} as FAT32..."
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
