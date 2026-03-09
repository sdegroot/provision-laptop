# Implementation Progress

Tracking implementation status per phase from `plan.md`.

## Phase 0: VM Setup on macOS — DONE, VERIFIED
- [x] `tests/vm/download-iso.sh`
- [x] `tests/vm/create-vm.sh` — fixed: blank EFI vars, virtio-blk-pci disk
- [x] `tests/vm/start-vm.sh` — fixed: ramfb display, USB ISO boot, cocoa display
- [x] `tests/vm/ssh-vm.sh` — default user: sdegroot
- [x] `tests/vm/destroy-vm.sh`
- [x] `tests/vm/README.md`
- [x] `Makefile`
- [x] Verified: VM boots, Fedora Silverblue 41 aarch64 installed, SSH works

## Phase 1: Kickstart — DONE, VERIFIED IN VM
- [x] `kickstart/base.ks` — updated: user=sdegroot
- [x] `kickstart/vm-single-disk.ks` — sdegroot user, SSH password auth, passwordless sudo
- [x] `kickstart/laptop-dual-disk.ks` — LUKS2 on both NVMe drives (not yet tested)
- [x] `kickstart/includes/partitioning-vm.ks` — Btrfs, no LUKS (VM only)
- [x] `kickstart/includes/partitioning-laptop.ks` — LUKS2 + Btrfs (for real hardware)
- [x] `tests/vm/kickstart-install.sh` — OEMDRV approach: flattens kickstart, creates FAT12 disk, QEMU boot
- [x] `Makefile` — added `vm-kickstart` target
- [x] End-to-end kickstart install verified: Btrfs subvolumes, passwordless sudo, SSH all working

## Phase 2: Bootstrap — Files Written, Not Yet Tested
- [x] `kickstart/includes/post-install.sh`
- [x] `bootstrap/first-boot.sh`
- [x] `bootstrap/first-boot.service`
- [ ] End-to-end first-boot test

## Phase 3: Repository Skeleton + Engine Framework — DONE, VERIFIED
- [x] `.gitignore`, `README.md`, `CHANGELOG.md`
- [x] `lib/common.sh` — fixed: ~/.local/bin in PATH for non-interactive shells
- [x] `lib/engine.sh` — fixed: arithmetic exit code bug with (( count++ ))
- [x] `lib/modules/order.conf` — 8 modules
- [x] `bin/install`, `bin/apply`, `bin/check`, `bin/plan`
- [x] `lib/modules/directories/{check,apply,plan}.sh`
- [x] `state/directories.txt`
- [x] `tests/run.sh`, `tests/helpers.sh`
- [x] `tests/test_common.sh`, `tests/test_engine.sh`, `tests/test_module_directories.sh`
- [x] 42 unit tests passing on macOS

## Phase 4: Core State Modules — DONE, VERIFIED IN VM
- [x] `state/flatpaks.txt` — Signal commented out (no aarch64 build)
- [x] `state/host-packages.txt`
- [x] `lib/modules/flatpaks/{check,apply,plan}.sh` — fixed: sudo for system installs
- [x] `lib/modules/host-packages/{check,apply,plan}.sh` — fixed: sudo for rpm-ostree
- [x] `tests/test_module_flatpaks.sh`, `tests/test_module_host_packages.sh`
- [x] Verified: all flatpaks installed, host packages layered

## Phase 5: Dotfiles Module — DONE, VERIFIED IN VM
- [x] `lib/modules/dotfiles/{check,apply,plan}.sh`
- [x] `dotfiles/` (.gitconfig, .bashrc, .config/starship.toml, .ssh/config)
- [x] `tests/test_module_dotfiles.sh`
- [x] Verified: all dotfiles symlinked, .bashrc backed up

## Phase 6: Security Configuration — DONE, VERIFIED IN VM
- [x] `dotfiles/.ssh/config` — 1Password agent integration
- [x] `lib/modules/security/{check,apply,plan}.sh` — fixed: sudo for firewall-cmd
- [x] `docs/yubikey-setup.md`, `docs/1password-setup.md`, `docs/security-model.md`
- [x] Verified: firewall active, SSH config correct

## Phase 7: Toolbox Profiles — DONE, VERIFIED IN VM
- [x] `state/toolbox-profiles.yml`
- [x] `toolbox/base-setup.sh`
- [x] `toolbox/profiles/dev-base.sh`, `dev-web.sh`, `dev-python.sh`, `dev-infra.sh`
- [x] `lib/modules/toolboxes/{check,apply,plan}.sh` — fixed: --assumeyes flag
- [x] `lib/yaml.sh`
- [x] `tests/test_module_toolboxes.sh`
- [x] Verified: all 4 toolboxes created with packages installed

### Known issues — RESOLVED
- ~~dev-web: npm global install needs `sudo` in toolbox~~ — fixed: added `sudo` to `npm install -g`
- ~~dev-python: pipx not on PATH after pip install --user~~ — fixed: install pipx via `dnf` instead of pip
- ~~dev-infra: `terraform` not in Fedora repos~~ — fixed: added HashiCorp repo in setup script, removed from dnf packages

## Phase 8: Mise Runtime Management — DONE, VERIFIED IN VM
- [x] `mise/mise.toml`
- [x] `lib/modules/mise/{check,apply,plan}.sh`
- [x] `tests/test_module_mise.sh`
- [x] Verified: mise installed, config symlinked

## Phase 9: Podman Sandbox Containers — DONE, VERIFIED IN VM
- [x] `containers/ai-sandbox/Containerfile`, `run.sh`
- [x] `state/containers.conf`
- [x] `lib/modules/containers/{check,apply,plan}.sh`
- [x] Verified: ai-sandbox image built

## Phase 10: USB Installer — Files Written, Not Yet Tested
- [x] `usb/make-usb.sh`
- [x] `usb/patch-grub.sh`
- [x] `docs/usb-installer.md`

## Phase 11: Smoke Tests — Framework Written, Not Yet Run
- [x] `tests/vm/run-smoke-tests.sh`
- [x] `tests/smoke/test_*.sh`
- [x] `docs/testing.md`

## VM Verification Summary

Full `bin/check` in Fedora Silverblue 41 VM: **8/8 modules passed**.

```
directories     ✓
host-packages   ✓
flatpaks        ✓
dotfiles        ✓
security        ✓
mise            ✓
toolboxes       ✓
containers      ✓
```

## Remaining Work
- [ ] Kickstart automated install (HTTP serving + end-to-end test)
- [ ] First-boot service end-to-end test
- [ ] Fix toolbox profile setup scripts (npm sudo, pipx PATH, terraform repo)
- [ ] USB installer testing on real hardware
- [ ] Run smoke tests in VM
- [ ] Customize state files for real user preferences
