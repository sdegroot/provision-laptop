# partitioning-laptop.ks — Dual-disk LUKS + Btrfs for laptop.
#
# Disk 1 (NVMe system): /dev/nvme0n1
# Disk 2 (NVMe data):   /dev/nvme1n1
#
# Adjust device names as needed for your hardware.

# Clear all partitions on both disks
zerombr
clearpart --all --initlabel --disklabel=gpt --drives=nvme0n1,nvme1n1

# --- Disk 1: System ---

# EFI System Partition
part /boot/efi --fstype=efi --size=512 --ondisk=nvme0n1

# Boot partition
part /boot --fstype=ext4 --size=1024 --ondisk=nvme0n1

# System LUKS partition
part pv.system --size=1 --grow --encrypted --luks-version=luks2 --passphrase=changeme --ondisk=nvme0n1

# System Btrfs
btrfs none --label=system pv.system
btrfs / --subvol --name=root LABEL=system
btrfs /var --subvol --name=var LABEL=system
btrfs /var/lib/containers --subvol --name=containers LABEL=system

# --- Disk 2: Data ---

# Data LUKS partition
part pv.data --size=1 --grow --encrypted --luks-version=luks2 --passphrase=changeme --ondisk=nvme1n1

# Data Btrfs
btrfs none --label=data pv.data
btrfs /home --subvol --name=home LABEL=data
btrfs /work --subvol --name=work LABEL=data
btrfs /sandbox --subvol --name=sandbox LABEL=data
