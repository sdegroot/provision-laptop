# USB Installer

## Overview

Create a bootable USB drive that automatically installs Fedora Silverblue
with the project's kickstart configuration. The kickstart is embedded
directly into the ISO using `mkksiso` (official Fedora tool), ensuring
reliable automated installation.

## Prerequisites

- Fedora Silverblue x86_64 ISO (download with `tests/vm/download-iso.sh --arch x86_64`)
- USB drive (8GB minimum)
- `podman` or `docker` on macOS (for running mkksiso in a container)
- `sgdisk` — `brew install gptfdisk` on macOS

## Creating the USB

```bash
# WARNING: Replace /dev/diskN with your actual USB device!
# Check with: diskutil list (macOS) or lsblk (Linux)
usb/make-usb.sh --device /dev/diskN
```

This single command:

1. Flattens the kickstart (resolves `%include` directives)
2. Bundles the provisioning repo via `git archive`
3. Runs `mkksiso` in a container to embed the kickstart into the ISO
4. Writes the modified ISO to the USB drive
5. Creates an OEMDRV partition with the bundled repo

### How it works

The kickstart is embedded into the ISO itself using `mkksiso`, which
modifies the boot configuration so Anaconda loads it automatically.
This bypasses the unreliable OEMDRV partition detection during dracut
early boot (see `docs/usb-kickstart-fix.md` for the technical details).

The OEMDRV partition is still created for the repo bundle — the `%post`
script copies it to `/home/sdegroot/provision-laptop`. This works
reliably because `%post` runs in the full installer environment with
all kernel modules loaded.

## Boot and Install

1. Boot from USB (ensure UEFI boot, disable Secure Boot if needed)
2. The kickstart runs automatically — no manual selection needed
3. Installation proceeds unattended (partitions both NVMe drives, creates LUKS, etc.)
4. System reboots after installation

## After First Boot

1. **Change passwords:**
   ```bash
   passwd
   ```

2. **Enroll YubiKey for LUKS unlock:**
   ```bash
   sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p3
   sudo systemd-cryptenroll --fido2-device=auto /dev/nvme1n1p1
   ```

3. **Install & configure 1Password**, enable SSH agent

4. **Run provisioning:**
   ```bash
   cd ~/provision-laptop
   git remote set-url origin git@github.com:sdegroot/provision-laptop.git
   git pull && bin/apply
   ```

5. **Remove passwordless sudo** (after provisioning is complete):
   ```bash
   sudo rm /etc/sudoers.d/sdegroot
   ```

## Testing in VM First

Always test the kickstart in a VM before using on real hardware:

```bash
make vm-create
make vm-start
# Complete the install, verify everything works
make vm-destroy
```

## Troubleshooting

### "podman or docker is required"

Install podman on macOS:
```bash
brew install podman
podman machine init
podman machine start
```

### mkksiso fails in container

Ensure your container runtime can access the ISO directory. On macOS with
Podman, the Podman machine VM needs access to the file paths being mounted.

### OEMDRV repo bundle not found during install

The `%post` script handles this gracefully — it prints a warning and suggests
cloning manually after first boot. The kickstart itself still works without it.
