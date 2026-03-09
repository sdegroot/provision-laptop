#!/usr/bin/env bash
# kickstart-install.sh — Automated Fedora Silverblue install via kickstart.
#
# This script:
# 1. Destroys any existing VM
# 2. Creates a fresh VM (disk + EFI vars)
# 3. Flattens the kickstart files into a single file
# 4. Extracts kernel + initrd from the ISO
# 5. Starts an HTTP server to serve the kickstart
# 6. Boots QEMU with kernel/initrd and inst.ks= parameter
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
KS_HTTP_PORT="${KS_HTTP_PORT:-8888}"

# Temp directory for extracted files
WORK_DIR="${SCRIPT_DIR}/.ks-work"

cleanup() {
    # Kill HTTP server if running
    if [[ -n "${HTTP_PID:-}" ]] && kill -0 "$HTTP_PID" 2>/dev/null; then
        echo "Stopping HTTP server (PID: ${HTTP_PID})..."
        kill "$HTTP_PID" 2>/dev/null || true
        wait "$HTTP_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

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

# Also check for .bak (renamed to prevent boot-from-ISO)
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
KS_FLAT="${WORK_DIR}/vm-single-disk.ks"

echo "Flattening kickstart files..."

flatten_kickstart() {
    local ks_file="$1"
    local ks_dir
    ks_dir="$(dirname "$ks_file")"

    while IFS= read -r line; do
        if [[ "$line" =~ ^%include[[:space:]]+(.+)$ ]]; then
            local include_path="${BASH_REMATCH[1]}"
            # Resolve relative to the kickstart file's directory
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
# Step 5: Extract kernel + initrd from ISO
# -------------------------------------------------------------------------

KERNEL="${WORK_DIR}/vmlinuz"
INITRD="${WORK_DIR}/initrd.img"

if [[ ! -f "$KERNEL" || ! -f "$INITRD" ]]; then
    echo "Extracting kernel and initrd from ISO..."

    # Mount the ISO and copy kernel/initrd
    ISO_MOUNT="${WORK_DIR}/iso-mount"
    mkdir -p "$ISO_MOUNT"

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: use hdiutil
        hdiutil attach -readonly -nobrowse -mountpoint "$ISO_MOUNT" "$ISO_PATH"
        cp "${ISO_MOUNT}/images/pxeboot/vmlinuz" "$KERNEL"
        cp "${ISO_MOUNT}/images/pxeboot/initrd.img" "$INITRD"
        hdiutil detach "$ISO_MOUNT"
    else
        # Linux: use mount
        sudo mount -o loop,ro "$ISO_PATH" "$ISO_MOUNT"
        cp "${ISO_MOUNT}/images/pxeboot/vmlinuz" "$KERNEL"
        cp "${ISO_MOUNT}/images/pxeboot/initrd.img" "$INITRD"
        sudo umount "$ISO_MOUNT"
    fi

    echo "Extracted kernel: ${KERNEL}"
    echo "Extracted initrd: ${INITRD}"
else
    echo "Using cached kernel and initrd"
fi

# -------------------------------------------------------------------------
# Step 6: Start HTTP server for kickstart
# -------------------------------------------------------------------------

echo "Starting HTTP server on port ${KS_HTTP_PORT} to serve kickstart..."
python3 -m http.server "$KS_HTTP_PORT" --directory "$WORK_DIR" &>/dev/null &
HTTP_PID=$!
sleep 1

if ! kill -0 "$HTTP_PID" 2>/dev/null; then
    echo "ERROR: Failed to start HTTP server on port ${KS_HTTP_PORT}"
    echo "Is another process using that port?"
    exit 1
fi
echo "HTTP server running (PID: ${HTTP_PID})"
echo "Kickstart URL: http://10.0.2.2:${KS_HTTP_PORT}/vm-single-disk.ks"

# -------------------------------------------------------------------------
# Step 7: Find EFI firmware
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
# Step 8: Boot VM with kickstart
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
echo "  Kickstart: http://10.0.2.2:${KS_HTTP_PORT}/vm-single-disk.ks"
echo "=========================================="
echo ""
echo "The Anaconda installer will run automatically."
echo "When done, the VM will reboot into the installed system."
echo ""

# Kernel boot arguments for the installer
# inst.ks=  — kickstart URL
# inst.stage2= — where to find the installer image (the ISO)
# console=ttyAMA0 — serial console for headless operation
KERNEL_ARGS="inst.ks=http://10.0.2.2:${KS_HTTP_PORT}/vm-single-disk.ks inst.stage2=cdrom quiet"

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
    # ISO as usb-storage (same as start-vm.sh)
    -drive "file=${ISO_PATH},format=raw,if=none,id=cd0,media=cdrom,readonly=on"
    -device usb-storage,drive=cd0
    # Direct kernel boot with kickstart parameter
    -kernel "$KERNEL"
    -initrd "$INITRD"
    -append "$KERNEL_ARGS"
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
