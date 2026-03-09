# USB Installer

## Overview

Create a bootable USB drive that automatically installs Fedora Silverblue
with the project's kickstart configuration.

## Prerequisites

- Fedora Silverblue ISO (download with `tests/vm/download-iso.sh`)
- USB drive (8GB minimum)
- Kickstart file (`kickstart/vm-single-disk.ks` or `kickstart/laptop-dual-disk.ks`)

## Creating the USB

### Step 1: Write ISO to USB

```bash
# WARNING: Replace /dev/sdX with your actual USB device!
usb/make-usb.sh --device /dev/sdX --kickstart kickstart/laptop-dual-disk.ks
```

### Step 2: Add Kickstart (OEMDRV method)

The simplest approach is to create a small partition labeled `OEMDRV`:

1. After writing the ISO, create a small (100MB) partition on the remaining space
2. Format it: `mkfs.vfat -n OEMDRV /dev/sdXN`
3. Mount it and copy the kickstart file as `ks.cfg`
4. Anaconda will automatically detect and use it

### Step 3: Boot and Install

1. Boot from USB
2. If using OEMDRV, the kickstart runs automatically
3. If not, press Tab at the boot menu and add: `inst.ks=hd:LABEL=OEMDRV:/ks.cfg`

## Important Notes

- **LUKS passphrase:** The kickstart uses a temporary passphrase. Change it after first boot:
  ```bash
  sudo cryptsetup luksChangeKey /dev/nvme0n1p3
  ```
- **User password:** Change the default password immediately: `passwd`
- **Sudo access:** Remove passwordless sudo after provisioning:
  ```bash
  sudo rm /etc/sudoers.d/admin
  ```

## Testing in VM First

Always test the kickstart in a VM before using on real hardware:

```bash
make vm-create
make vm-start
# Complete the install, verify everything works
make vm-destroy
```
