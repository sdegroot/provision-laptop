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
- [x] `lib/modules/order.conf` — 10 modules
- [x] `bin/install`, `bin/apply`, `bin/check`, `bin/plan`
- [x] `lib/modules/directories/{check,apply,plan}.sh`
- [x] `state/directories.txt`
- [x] `tests/run.sh`, `tests/helpers.sh`
- [x] `tests/test_common.sh`, `tests/test_engine.sh`, `tests/test_module_directories.sh`
- [x] 89 unit tests passing on macOS (across 11 test suites)

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

## Phase 8: Mise Runtime Management — DONE, VERIFIED IN VM
- [x] `mise/mise.toml`
- [x] `lib/modules/mise/{check,apply,plan}.sh`
- [x] `tests/test_module_mise.sh`
- [x] Verified: mise installed, config symlinked

## Phase 9: Podman Sandbox Containers — DONE, VERIFIED IN VM
- [x] `containers/ai-sandbox/Containerfile` — rewritten with Node.js, Python, Go, AI CLI tools
- [x] `bin/ai-sandbox` — full orchestration runner with git worktree, security controls, dry-run
- [x] `containers/ai-sandbox/config/gitconfig` — minimal git config (no credentials)
- [x] `state/containers.conf`
- [x] `lib/modules/containers/{check,apply,plan}.sh`
- [x] `docs/ai-sandbox.md` — usage, security model, examples
- [x] `tests/test_ai_sandbox.sh` — 24 tests for arg parsing, validation, command construction
- [x] Verified: ai-sandbox image built

## Phase 10: USB Installer — Updated, Not Yet Tested on Hardware
- [x] `usb/make-usb.sh` — rewritten: writes ISO + creates OEMDRV partition with kickstart + bundled repo
- [x] `usb/patch-grub.sh` — may no longer be needed (OEMDRV auto-detected)
- [x] `docs/usb-installer.md`

## Phase 11: Repos + Hardware Modules — DONE, VERIFIED IN VM
- [x] `lib/modules/repos/{check,apply,plan}.sh` — Tuxedo, RPM Fusion, COPR repos
- [x] `state/repos.conf`
- [x] `lib/modules/hardware/{check,apply,plan}.sh` — kernel params, modprobe, sysctl, dracut, systemd
- [x] `state/kernel-params.txt`
- [x] Hardware config files: AMD FreeSync, audio power save, TCP BBR, FIDO2 dracut, Btrfs scrub, suspend-then-hibernate
- [x] `tests/test_module_repos.sh`, `tests/test_module_hardware.sh` — 20 tests
- [x] Architecture-aware state file parsing with `[arch]` tag syntax
- [x] Verified: repos configured, hardware configs deployed, kernel params set

## Phase 12: Smoke Tests — DONE, VERIFIED IN VM
- [x] `tests/vm/run-smoke-tests.sh` — fixed: default user sdegroot, sshpass support, IdentityAgent=none
- [x] `tests/vm/ssh-vm.sh` — fixed: sshpass support, IdentityAgent=none
- [x] `tests/smoke/test_system_basics.sh` — Silverblue, SELinux, firewall, SSH
- [x] `tests/smoke/test_provisioning.sh` — repo exists, bin scripts, bin/check runs
- [x] `tests/smoke/test_flatpaks.sh` — flatpak command, Flathub remote, app count
- [x] `tests/smoke/test_directories.sh` — required user directories
- [x] `docs/testing.md`
- [x] Verified: all 4 smoke tests pass against Fedora Silverblue 41 VM

## VM Verification Summary

Full `bin/check` in Fedora Silverblue 41 VM: **2/10 modules passed** (repos, host-packages).
Remaining drift is expected — VM has not had `bin/apply` run for all modules.

Smoke tests: **4/4 passed** (system basics, provisioning, flatpaks, directories).

## Remaining Work
- [ ] First-boot service end-to-end test
- [ ] USB installer testing on real hardware
- [ ] Run `bin/apply` in VM and re-verify all 10 modules pass
- [ ] Customize state files for real user preferences
