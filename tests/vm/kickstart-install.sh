#!/usr/bin/env bash
# kickstart-install.sh — Automated Fedora Silverblue install via kickstart.
#
# This script:
# 1. Destroys any existing VM
# 2. Creates a fresh VM (disk + EFI vars)
# 3. Flattens the kickstart files into a single file
# 4. Creates a small FAT32 disk image labeled OEMDRV with ks.cfg on it
#    (Anaconda auto-detects OEMDRV volumes and loads ks.cfg)
# 5. Boots QEMU from the ISO with the OEMDRV disk attached
#
# After install completes, the VM reboots into the installed system.
# SSH should be available on localhost:2222.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# VM configuration
VM_NAME="${VM_NAME:-silverblue-test}"
VM_DISK="${SCRIPT_DIR}/${VM_NAME}.qcow2"
VM_DISK_SIZE="${VM_DISK_SIZE:-60G}"
VM_MEMORY="${VM_MEMORY:-4096}"
VM_CPUS="${VM_CPUS:-4}"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_EFIVARS="${SCRIPT_DIR}/${VM_NAME}-efivars.fd"

# Temp directory for work files
WORK_DIR="${SCRIPT_DIR}/.ks-work"

# -------------------------------------------------------------------------
# Step 1: Find ISO
# -------------------------------------------------------------------------

ISO_PATH=""
for iso in "${SCRIPT_DIR}"/Fedora-Silverblue-ostree-aarch64-*.iso; do
    if [[ -f "$iso" ]]; then
        ISO_PATH="$iso"
        break
    fi
done

# Also check for .bak (renamed to prevent boot-from-ISO on subsequent boots)
if [[ -z "$ISO_PATH" ]]; then
    for iso in "${SCRIPT_DIR}"/Fedora-Silverblue-ostree-aarch64-*.iso.bak; do
        if [[ -f "$iso" ]]; then
            ISO_PATH="$iso"
            break
        fi
    done
fi

if [[ -z "$ISO_PATH" ]]; then
    echo "ERROR: No Fedora Silverblue ISO found in ${SCRIPT_DIR}"
    echo "Run: tests/vm/download-iso.sh"
    exit 1
fi

echo "Using ISO: ${ISO_PATH}"

# -------------------------------------------------------------------------
# Step 2: Destroy existing VM
# -------------------------------------------------------------------------

if [[ -f "$VM_DISK" ]]; then
    echo "Destroying existing VM..."
    "${SCRIPT_DIR}/destroy-vm.sh" || true
fi

# -------------------------------------------------------------------------
# Step 3: Create fresh VM
# -------------------------------------------------------------------------

echo "Creating VM disk: ${VM_DISK} (${VM_DISK_SIZE})"
qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"

echo "Creating blank EFI vars file..."
dd if=/dev/zero of="$VM_EFIVARS" bs=1m count=64 2>/dev/null

# -------------------------------------------------------------------------
# Step 4: Flatten kickstart
# -------------------------------------------------------------------------

mkdir -p "$WORK_DIR"
KS_FLAT="${WORK_DIR}/ks.cfg"

echo "Flattening kickstart files..."

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

flatten_kickstart "${REPO_DIR}/kickstart/vm-single-disk.ks" > "$KS_FLAT"

echo "Flattened kickstart written to: ${KS_FLAT}"

# -------------------------------------------------------------------------
# Step 5: Create OEMDRV disk image
# -------------------------------------------------------------------------
# Anaconda automatically loads ks.cfg from any volume labeled OEMDRV.
# We create a small FAT32 disk image with the flattened kickstart on it.

OEMDRV_IMG="${WORK_DIR}/oemdrv.img"

echo "Creating OEMDRV disk image..."

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: create a DMG, convert to raw image
    OEMDRV_DMG="${WORK_DIR}/oemdrv.dmg"
    OEMDRV_MOUNT="${WORK_DIR}/oemdrv-mount"

    # Remove old files
    rm -f "$OEMDRV_DMG" "$OEMDRV_IMG"

    # Create a 2MB FAT disk image with volume name OEMDRV
    hdiutil create -size 2m -fs "MS-DOS FAT12" -volname OEMDRV -layout NONE "$OEMDRV_DMG"

    # Mount, copy kickstart, unmount
    mkdir -p "$OEMDRV_MOUNT"
    hdiutil attach -readwrite -nobrowse -mountpoint "$OEMDRV_MOUNT" "$OEMDRV_DMG"
    cp "$KS_FLAT" "${OEMDRV_MOUNT}/ks.cfg"
    hdiutil detach "$OEMDRV_MOUNT"

    # Convert to raw image for QEMU
    hdiutil convert "$OEMDRV_DMG" -format UDTO -o "${WORK_DIR}/oemdrv.cdr"
    mv "${WORK_DIR}/oemdrv.cdr" "$OEMDRV_IMG"
    rm -f "$OEMDRV_DMG"
else
    # Linux: use mkfs.vfat and mount
    dd if=/dev/zero of="$OEMDRV_IMG" bs=1m count=2 2>/dev/null
    mkfs.vfat -n OEMDRV "$OEMDRV_IMG"
    OEMDRV_MOUNT="${WORK_DIR}/oemdrv-mount"
    mkdir -p "$OEMDRV_MOUNT"
    sudo mount -o loop "$OEMDRV_IMG" "$OEMDRV_MOUNT"
    cp "$KS_FLAT" "${OEMDRV_MOUNT}/ks.cfg"
    sudo umount "$OEMDRV_MOUNT"
fi

echo "OEMDRV disk image created with ks.cfg"

# -------------------------------------------------------------------------
# Step 6: Find EFI firmware
# -------------------------------------------------------------------------

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
    echo "Install QEMU: brew install qemu"
    exit 1
fi

# -------------------------------------------------------------------------
# Step 7: Boot VM with ISO + OEMDRV
# -------------------------------------------------------------------------

PID_DIR="${SCRIPT_DIR}/pid"
mkdir -p "$PID_DIR"
PID_FILE="${PID_DIR}/${VM_NAME}.pid"

echo ""
echo "=========================================="
echo "  Starting automated Fedora Silverblue install"
echo "  VM: ${VM_NAME}"
echo "  Memory: ${VM_MEMORY}MB, CPUs: ${VM_CPUS}"
echo "  SSH will be on localhost:${VM_SSH_PORT}"
echo "  Kickstart: via OEMDRV volume (auto-detected by Anaconda)"
echo "=========================================="
echo ""
echo "The Anaconda installer will boot from ISO and auto-detect"
echo "the kickstart from the OEMDRV volume."
echo ""
echo "IMPORTANT: After install completes and the VM reboots,"
echo "close the QEMU window, then start with: make vm-start"
echo "(to boot without the ISO attached)"
echo ""

QEMU_ARGS=(
    -name "$VM_NAME"
    -machine virt,accel=hvf,highmem=on
    -cpu host
    -m "$VM_MEMORY"
    -smp "$VM_CPUS"
    -drive "if=pflash,format=raw,file=${EFI_CODE},readonly=on"
    -drive "if=pflash,format=raw,file=${VM_EFIVARS}"
    # Main disk
    -drive "file=${VM_DISK},format=qcow2,if=none,id=hd0"
    -device virtio-blk-pci,drive=hd0
    # OEMDRV disk (kickstart source — Anaconda auto-detects)
    -drive "file=${OEMDRV_IMG},format=raw,if=none,id=oemdrv"
    -device virtio-blk-pci,drive=oemdrv
    # Network
    -device virtio-net-pci,netdev=net0
    -netdev "user,id=net0,hostfwd=tcp::${VM_SSH_PORT}-:22"
    # USB devices
    -device qemu-xhci
    -device usb-kbd
    -device usb-tablet
    # ISO as usb-storage
    -drive "file=${ISO_PATH},format=raw,if=none,id=cd0,media=cdrom,readonly=on"
    -device usb-storage,drive=cd0
    -pidfile "$PID_FILE"
)

# Display mode
if [[ "${VM_NOGRAPHIC:-}" == "1" ]]; then
    QEMU_ARGS+=(-nographic)
else
    QEMU_ARGS+=(-device ramfb)
    QEMU_ARGS+=(-display cocoa)
fi

echo "Launching QEMU..."
qemu-system-aarch64 "${QEMU_ARGS[@]}" \
    || { echo "QEMU exited"; }

echo ""
echo "VM window closed. If the install completed successfully:"
echo "  1. Start the VM:  tests/vm/start-vm.sh"
echo "  2. Connect:       tests/vm/ssh-vm.sh"
echo "  3. SSH password:  changeme"
