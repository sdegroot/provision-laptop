# Implementation Progress

Tracking implementation status per phase from `plan.md`.

## Phase 0: VM Setup on macOS
- [ ] `tests/vm/download-iso.sh`
- [ ] `tests/vm/create-vm.sh`
- [ ] `tests/vm/start-vm.sh`
- [ ] `tests/vm/ssh-vm.sh`
- [ ] `tests/vm/destroy-vm.sh`
- [ ] `tests/vm/README.md`
- [ ] `Makefile`

## Phase 1: Kickstart — Automated OS Install
- [ ] `kickstart/base.ks`
- [ ] `kickstart/vm-single-disk.ks`
- [ ] `kickstart/laptop-dual-disk.ks`
- [ ] `kickstart/includes/partitioning-vm.ks`
- [ ] `kickstart/includes/partitioning-laptop.ks`
- [ ] Update `tests/vm/create-vm.sh` for kickstart integration

## Phase 2: Bootstrap — Post-Install First Boot
- [ ] `kickstart/includes/post-install.sh`
- [ ] `bootstrap/first-boot.sh`
- [ ] `bootstrap/first-boot.service`

## Phase 3: Repository Skeleton + Engine Framework
- [x] `.gitignore`
- [x] `README.md`
- [x] `CHANGELOG.md`
- [x] `lib/common.sh`
- [x] `lib/engine.sh`
- [x] `lib/modules/order.conf`
- [ ] `bin/install`
- [ ] `bin/apply`
- [ ] `bin/check`
- [ ] `bin/plan`
- [ ] `lib/modules/directories/{check,apply,plan}.sh`
- [ ] `state/directories.txt`
- [ ] `tests/run.sh`
- [ ] `tests/helpers.sh`
- [ ] `tests/test_common.sh`
- [ ] `tests/test_engine.sh`
- [ ] `tests/test_module_directories.sh`

## Phase 4: Core State Modules (Flatpaks + Host Packages)
- [ ] `state/flatpaks.txt`
- [ ] `state/host-packages.txt`
- [ ] `lib/modules/flatpaks/{check,apply,plan}.sh`
- [ ] `lib/modules/host-packages/{check,apply,plan}.sh`
- [ ] `tests/test_module_flatpaks.sh`
- [ ] `tests/test_module_host_packages.sh`

## Phase 5: Dotfiles Module
- [ ] `lib/modules/dotfiles/{check,apply,plan}.sh`
- [ ] `dotfiles/` initial files
- [ ] `tests/test_module_dotfiles.sh`

## Phase 6: Security Configuration
- [ ] `dotfiles/.ssh/config`
- [ ] `lib/modules/security/{check,apply,plan}.sh`
- [ ] `docs/yubikey-setup.md`
- [ ] `docs/1password-setup.md`
- [ ] `docs/security-model.md`

## Phase 7: Toolbox Profiles
- [ ] `state/toolbox-profiles.yml`
- [ ] `toolbox/base-setup.sh`
- [ ] `toolbox/profiles/dev-base.sh`, `dev-web.sh`, `dev-python.sh`, `dev-infra.sh`
- [ ] `lib/modules/toolboxes/{check,apply,plan}.sh`
- [ ] `tests/test_module_toolboxes.sh`

## Phase 8: Mise Runtime Management
- [ ] `mise/mise.toml`
- [ ] `lib/modules/mise/{check,apply,plan}.sh`
- [ ] `tests/test_module_mise.sh`

## Phase 9: Podman Sandbox Containers
- [ ] `containers/ai-sandbox/Containerfile`, `run.sh`
- [ ] `state/containers.conf`
- [ ] `lib/modules/containers/{check,apply,plan}.sh`

## Phase 10: USB Installer
- [ ] `usb/make-usb.sh`
- [ ] `usb/patch-grub.sh`
- [ ] `docs/usb-installer.md`

## Phase 11: Smoke Tests
- [ ] `tests/vm/run-smoke-tests.sh`
- [ ] `tests/smoke/test_*.sh`
- [ ] `docs/testing.md`
