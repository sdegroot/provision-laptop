# Fix USB Kickstart Loading with mkksiso

## Context

The USB installer created by `make-usb.sh` fails to load the kickstart during boot. We've been patching GRUB configs and trying various `inst.ks` / `inst.stage2` overrides, but the core issue is deeper.

**Root cause (from Anaconda/dracut source analysis):**

1. `inst.ks=hd:LABEL=OEMDRV:/ks.cfg` is processed by **dracut** during early boot (initramfs)
2. Dracut's `fetch-kickstart-disk` does `mount -o ro "$dev" "$tmpmnt"` with auto-detection — no fallbacks, silent failure
3. After dd'ing a Fedora ISO to USB, partition 1 starts at sector 0 (non-standard for GPT). This makes the partition table "technically invalid"
4. sgdisk CAN add partition 4 (OEMDRV), and the kernel DOES see it (`/dev/sda4`), but **dracut cannot mount it** during early boot
5. OEMDRV auto-detection also happens in dracut (not Anaconda) — same problem
6. The `extra_cmdline` approach works for injecting kernel params but doesn't fix the mount issue

**Why GRUB patching can't fix this:** The problem isn't GRUB or kernel params — it's that dracut's initramfs environment cannot reliably mount a partition that was added post-dd to a hybrid ISO partition table.

## Solution: mkksiso

`mkksiso` is the **official Fedora tool** (part of `lorax`) for creating kickstart-enabled ISOs. It embeds the kickstart INTO the ISO and modifies the boot configuration, completely bypassing the OEMDRV partition table issues.

### What mkksiso does:
- Embeds `ks.cfg` in the ISO root directory
- Automatically adds `inst.ks=file:///run/install/ks.cfg` to GRUB/isolinux boot configs
- Preserves `inst.stage2` (same ISO, correct label — no version mismatch)
- Preserves EFI boot capability
- Recalculates ISO checksums

### What we still need OEMDRV for:
- The **repo bundle** (`provision-laptop/`) — used by `%post` script
- `%post` runs in the full installer environment (all kernel modules loaded), so mounting FAT32 partitions works fine there — the issue is only during dracut early boot
- The kickstart's `%post` already handles OEMDRV-not-found gracefully (prints warning, suggests manual clone)

## New make-usb.sh Flow

1. Flatten kickstart → `$WORK_DIR/ks.cfg`
2. Bundle repo → `$WORK_DIR/provision-laptop/`
3. **NEW:** Run `mkksiso` in a container to create modified ISO
4. dd modified ISO to USB
5. Move GPT backup header (`sgdisk --move-second-header`)
6. Create OEMDRV partition for **repo bundle only** (no `ks.cfg` needed)
7. Format OEMDRV, copy repo bundle
8. Eject

### Container command for mkksiso:

```bash
# Try podman first, fall back to docker
CONTAINER_CMD=""
if command -v podman &>/dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
else
    echo "ERROR: podman or docker required for mkksiso"
    exit 1
fi

$CONTAINER_CMD run --rm \
    -v "${WORK_DIR}:/work:z" \
    -v "$(dirname "$ISO_PATH"):/iso:ro" \
    fedora:43 bash -c "
        dnf install -y lorax &&
        mkksiso --ks /work/ks.cfg \
            --cmdline 'rd.live.check=0' \
            /iso/$(basename "$ISO_PATH") \
            /work/modified.iso
    "
```

mkksiso requires Linux (`xorriso`, `isomd5sum`). On macOS, running in a container is the standard approach.

## What gets removed/simplified

- **`patch-grub.sh`**: No longer called from `make-usb.sh`. Keep the script for standalone/manual use, but it's not part of the primary flow.
- **GRUB extra_cmdline injection**: Not needed — mkksiso handles boot config
- **inst.stage2 label fix**: Not needed — mkksiso preserves the correct label
- **inst.ks kernel param**: Not needed — mkksiso adds it automatically
- **ks.cfg on OEMDRV**: Not needed — it's embedded in the ISO

## Files to Modify

### `usb/make-usb.sh`
- Add mkksiso step (container-based) between flatten/bundle and dd
- dd the **modified** ISO (not the original)
- OEMDRV partition: copy only repo bundle (remove ks.cfg copy)
- Remove call to `patch-grub.sh`
- Add container runtime detection (podman/docker)

### `usb/patch-grub.sh`
- Keep as-is for standalone use (no changes needed)
- No longer called from make-usb.sh

### `CHANGELOG.md`
- Document the switch to mkksiso

## Verification

1. Run `usb/make-usb.sh --device /dev/sdX` on macOS (requires podman or docker)
2. mkksiso step should complete without errors
3. Boot from USB on physical hardware
4. Installer should auto-load kickstart — no language/disk prompts
5. Installation proceeds unattended (selects nvme drives, creates LUKS, etc.)
6. `%post` should copy repo bundle from OEMDRV
7. After reboot: `/home/sdegroot/provision-laptop/` exists

## Prerequisite

User needs `podman` or `docker` on macOS:
```bash
brew install podman
podman machine init
podman machine start
```
Or Docker Desktop.
