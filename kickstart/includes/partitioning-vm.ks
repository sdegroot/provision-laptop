# partitioning-vm.ks — Simple partitioning for VM testing (no LUKS).
#
# Single virtio disk: /dev/vda
# LUKS is intentionally skipped for the VM to avoid passphrase prompts
# on every boot, which blocks headless/automated testing.
# The laptop kickstart (partitioning-laptop.ks) uses LUKS2 for real hardware.

zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --type=btrfs --noswap
