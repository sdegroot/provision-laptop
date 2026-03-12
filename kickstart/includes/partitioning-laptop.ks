# partitioning-laptop.ks — Dual-disk LUKS2 + Btrfs for laptop.
#
# Disk 1 (NVMe system): /dev/nvme0n1
# Disk 2 (NVMe data):   /dev/nvme1n1
#
# Adjust device names as needed for your hardware.
#
# LUKS passphrase is set to a temporary value during install.
# After first boot, enroll YubiKey via:
#   sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p3
#   sudo systemd-cryptenroll --fido2-device=auto /dev/nvme1n1p1
# Then optionally remove the temporary passphrase.

# Ignore all disks except the two NVMe drives (prevents Anaconda from
# prompting about the USB installer drive or any other attached storage)
ignoredisk --only-use=nvme0n1,nvme1n1

# Clear all partitions on both disks
zerombr
clearpart --all --initlabel --disklabel=gpt --drives=nvme0n1,nvme1n1

# --- Disk 1: System ---

# EFI System Partition (600MB — room for multiple kernels)
part /boot/efi --fstype=efi --size=600 --ondisk=nvme0n1

# Boot partition (outside LUKS — kernel/initrd must be readable)
part /boot --fstype=ext4 --size=1024 --ondisk=nvme0n1

# System LUKS2 partition (temporary passphrase, YubiKey enrolled after boot)
part btrfs.system --size=1 --grow --encrypted --luks-version=luks2 --passphrase=changeme --ondisk=nvme0n1

# System Btrfs subvolumes
btrfs none --label=system btrfs.system
btrfs / --subvol --name=root LABEL=system
btrfs /var --subvol --name=var LABEL=system
btrfs /var/lib/containers --subvol --name=containers LABEL=system
# Note: swap subvolume is NOT created here — Anaconda fails with "operation not
# permitted" when setting nodatacow on the mount point. The hardware module's
# apply_hibernate() creates it on first boot instead (see lib/modules/hardware/apply.sh).

# --- Disk 2: Data ---

# Data LUKS2 partition (same temporary passphrase)
part btrfs.data --size=1 --grow --encrypted --luks-version=luks2 --passphrase=changeme --ondisk=nvme1n1

# Data Btrfs subvolumes
btrfs none --label=data btrfs.data
btrfs /home --subvol --name=home LABEL=data
btrfs /var/work --subvol --name=work LABEL=data
btrfs /var/sandbox --subvol --name=sandbox LABEL=data
