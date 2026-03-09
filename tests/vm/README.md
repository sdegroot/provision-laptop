# VM Test Environment

Instructions for running a Fedora Silverblue test VM on macOS (Apple Silicon).

## Prerequisites

```bash
brew install qemu
```

## Quick Start (QEMU CLI)

```bash
# Download the Fedora Silverblue aarch64 ISO
tests/vm/download-iso.sh

# Create the VM (disk image + EFI vars)
tests/vm/create-vm.sh

# Start the VM (boots from ISO for initial install)
tests/vm/start-vm.sh

# After OS installation and reboot, SSH in:
tests/vm/ssh-vm.sh

# When done, tear down:
tests/vm/destroy-vm.sh
```

## Configuration

All scripts accept environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VM_NAME` | `silverblue-test` | VM name (used for disk/pid files) |
| `VM_DISK_SIZE` | `60G` | Disk image size (thin-provisioned) |
| `VM_MEMORY` | `4096` | Memory in MB |
| `VM_CPUS` | `4` | Number of CPU cores |
| `VM_SSH_PORT` | `2222` | Host port forwarded to VM port 22 |
| `VM_USER` | `admin` | SSH username |
| `FEDORA_VERSION` | `41` | Fedora release to download |

## Architecture

- Uses `qemu-system-aarch64` with HVF acceleration (Apple Hypervisor Framework) for native speed
- EFI boot via `edk2-aarch64-code.fd` (from Homebrew's QEMU)
- Thin-provisioned qcow2 disk (~60GB)
- User-mode networking with SSH port forward (`localhost:2222 -> VM:22`)

> **Note:** The VM runs aarch64 (ARM) Fedora Silverblue for fast native iteration on Apple Silicon.
> The provisioning scripts are architecture-agnostic. Final testing on x86_64 hardware happens later.

## UTM GUI Alternative

For a graphical experience, use [UTM](https://mac.getutm.app/):

1. Download UTM from the App Store or website
2. Create a new VM:
   - Type: Virtualize (not Emulate)
   - OS: Linux
   - Boot ISO: use the downloaded Fedora Silverblue aarch64 ISO
   - Memory: 4096 MB
   - CPU Cores: 4
   - Disk: 60 GB
3. Enable "Open VM Settings" before starting
4. In Network settings: add port forwarding `TCP localhost:2222 -> 22`
5. Start the VM and complete the Fedora Silverblue installation
6. After install, remove the ISO from the drive settings

## First-Time Installation

During the first boot from ISO, you'll go through the Anaconda installer:
1. Select language and keyboard
2. Choose installation destination (the virtio disk)
3. Create a user account (enable admin/sudo)
4. Enable SSH in the services section
5. Complete installation and reboot

Once rebooted, remove the ISO or it will boot from it again.

## Kickstart (Automated Install)

See Phase 1 in the implementation plan. Once kickstart files are ready, the VM creation
script will serve the kickstart file and pass `inst.ks=` to automate installation.
