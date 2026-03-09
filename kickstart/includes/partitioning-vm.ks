# partitioning-vm.ks — Single-disk LUKS + Btrfs for VM testing.
#
# Single virtio disk: /dev/vda

# Clear all partitions
zerombr
clearpart --all --initlabel --disklabel=gpt

# EFI System Partition
part /boot/efi --fstype=efi --size=512 --ondisk=vda

# Boot partition (outside LUKS)
part /boot --fstype=ext4 --size=1024 --ondisk=vda

# LUKS-encrypted partition for everything else
part pv.01 --size=1 --grow --encrypted --luks-version=luks2 --passphrase=temppass --ondisk=vda

# Btrfs volume on the encrypted partition
volgroup none
btrfs none --label=silverblue pv.01
btrfs / --subvol --name=root LABEL=silverblue
btrfs /home --subvol --name=home LABEL=silverblue
btrfs /var --subvol --name=var LABEL=silverblue
