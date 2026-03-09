# partitioning-vm.ks — Single-disk LUKS2 + Btrfs for VM testing.
#
# Single virtio disk: /dev/vda
# Uses LUKS2 with a test passphrase to match the real laptop setup.
# Passphrase: temppass (hardcoded for automated VM testing only)

zerombr
clearpart --all --initlabel --disklabel=gpt

# EFI System Partition
part /boot/efi --fstype=efi --size=512 --ondisk=vda

# Boot partition (outside LUKS)
part /boot --fstype=ext4 --size=1024 --ondisk=vda

# LUKS2-encrypted partition for the rest
part btrfs.01 --size=1 --grow --encrypted --luks-version=luks2 --passphrase=temppass --ondisk=vda

# Btrfs on the encrypted partition
btrfs none --label=silverblue btrfs.01
btrfs / --subvol --name=root LABEL=silverblue
btrfs /home --subvol --name=home LABEL=silverblue
btrfs /var --subvol --name=var LABEL=silverblue
