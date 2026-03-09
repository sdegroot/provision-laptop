# Implementation Progress

Tracking implementation status per phase from `plan.md`.

## Phase 0: VM Setup on macOS
- [x] `tests/vm/download-iso.sh`
- [x] `tests/vm/create-vm.sh`
- [x] `tests/vm/start-vm.sh`
- [x] `tests/vm/ssh-vm.sh`
- [x] `tests/vm/destroy-vm.sh`
- [x] `tests/vm/README.md`
- [x] `Makefile`

## Phase 1: Kickstart — Automated OS Install
- [x] `kickstart/base.ks`
- [x] `kickstart/vm-single-disk.ks`
- [x] `kickstart/laptop-dual-disk.ks`
- [x] `kickstart/includes/partitioning-vm.ks`
- [x] `kickstart/includes/partitioning-laptop.ks`
- [ ] Update `tests/vm/create-vm.sh` for kickstart HTTP serving

## Phase 2: Bootstrap — Post-Install First Boot
- [x] `kickstart/includes/post-install.sh`
- [x] `bootstrap/first-boot.sh`
- [x] `bootstrap/first-boot.service`

## Phase 3: Repository Skeleton + Engine Framework
- [x] `.gitignore`
- [x] `README.md`
- [x] `CHANGELOG.md`
- [x] `lib/common.sh`
- [x] `lib/engine.sh`
- [x] `lib/modules/order.conf`
- [x] `bin/install`
- [x] `bin/apply`
- [x] `bin/check`
- [x] `bin/plan`
- [x] `lib/modules/directories/{check,apply,plan}.sh`
- [x] `state/directories.txt`
- [x] `tests/run.sh`
- [x] `tests/helpers.sh`
- [x] `tests/test_common.sh`
- [x] `tests/test_engine.sh`
- [x] `tests/test_module_directories.sh`

## Phase 4: Core State Modules (Flatpaks + Host Packages)
- [x] `state/flatpaks.txt`
- [x] `state/host-packages.txt`
- [x] `lib/modules/flatpaks/{check,apply,plan}.sh`
- [x] `lib/modules/host-packages/{check,apply,plan}.sh`
- [x] `tests/test_module_flatpaks.sh`
- [x] `tests/test_module_host_packages.sh`

## Phase 5: Dotfiles Module
- [x] `lib/modules/dotfiles/{check,apply,plan}.sh`
- [x] `dotfiles/` initial files (.gitconfig, .bashrc, .config/starship.toml)
- [x] `tests/test_module_dotfiles.sh`

## Phase 6: Security Configuration
- [x] `dotfiles/.ssh/config`
- [x] `lib/modules/security/{check,apply,plan}.sh`
- [x] `docs/yubikey-setup.md`
- [x] `docs/1password-setup.md`
- [x] `docs/security-model.md`

## Phase 7: Toolbox Profiles
- [x] `state/toolbox-profiles.yml`
- [x] `toolbox/base-setup.sh`
- [x] `toolbox/profiles/dev-base.sh`, `dev-web.sh`, `dev-python.sh`, `dev-infra.sh`
- [x] `lib/modules/toolboxes/{check,apply,plan}.sh`
- [x] `lib/yaml.sh`
- [x] `tests/test_module_toolboxes.sh`

## Phase 8: Mise Runtime Management
- [x] `mise/mise.toml`
- [x] `lib/modules/mise/{check,apply,plan}.sh`
- [x] `tests/test_module_mise.sh`

## Phase 9: Podman Sandbox Containers
- [x] `containers/ai-sandbox/Containerfile`, `run.sh`
- [x] `state/containers.conf`
- [x] `lib/modules/containers/{check,apply,plan}.sh`

## Phase 10: USB Installer
- [x] `usb/make-usb.sh`
- [x] `usb/patch-grub.sh`
- [x] `docs/usb-installer.md`

## Phase 11: Smoke Tests
- [x] `tests/vm/run-smoke-tests.sh`
- [x] `tests/smoke/test_*.sh`
- [x] `docs/testing.md`

## Remaining Work
- [ ] Kickstart HTTP serving integration in `tests/vm/create-vm.sh`
- [ ] Real VM testing (download ISO, boot, verify kickstart flow)
- [ ] Customize dotfiles/state files for actual user preferences
