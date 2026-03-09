# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Automated kickstart install script (`tests/vm/kickstart-install.sh`) using OEMDRV
  volume for kickstart auto-detection by Anaconda
- `make vm-kickstart` target for one-command automated VM install
- Laptop kickstart (`laptop-dual-disk.ks`): LUKS2, YubiKey support (FIDO2), 1Password
  packages, bundled repo from OEMDRV, no SSH
- USB installer (`usb/make-usb.sh`): creates bootable USB with ISO + OEMDRV partition
  containing flattened kickstart and bundled repo
- FIDO2 dracut configuration for YubiKey LUKS unlock at boot

### Fixed
- dev-web toolbox: added `sudo` to `npm install -g` for global package installs
- dev-python toolbox: install pipx via dnf instead of pip (fixes PATH issue)
- dev-infra toolbox: add HashiCorp repo for terraform, removed from dnf packages list
- dev-infra toolbox: detect architecture for correct AWS CLI installer URL

### Changed
- Kickstart user changed from `admin` to `sdegroot`
- VM kickstart: SSH + password auth enabled (for testing from host)
- Laptop kickstart: SSH disabled, firewall without SSH, YubiKey/FIDO2 packages layered
- Split base.ks: SSH/firewall settings moved to environment-specific kickstart files
- USB installer rewritten: creates OEMDRV partition with kickstart + bundled repo
- first-boot.sh simplified: no longer clones from GitHub, uses bundled repo

### Added
- Project skeleton with README, .gitignore, Makefile
- Reconciliation engine framework (lib/common.sh, lib/engine.sh)
- CLI tools: bin/install, bin/apply, bin/check, bin/plan
- Module system with order.conf-based sequential execution
- 8 provisioning modules:
  - **directories** — create directories from state/directories.txt
  - **host-packages** — rpm-ostree layered packages from state/host-packages.txt
  - **flatpaks** — Flatpak apps from state/flatpaks.txt with Flathub auto-config
  - **dotfiles** — convention-based symlinks from dotfiles/ into $HOME with backup
  - **security** — SSH config, 1Password agent, firewall verification
  - **mise** — runtime version manager installation and config
  - **toolboxes** — YAML-based toolbox profiles (dev-base, dev-web, dev-python, dev-infra)
  - **containers** — Podman sandbox containers (ai-sandbox)
- Kickstart files for automated Fedora Silverblue installation:
  - VM single-disk (LUKS2 + Btrfs on virtio)
  - Laptop dual-disk (system + data NVMe drives)
- Bootstrap/first-boot automation (systemd service, post-install script)
- VM test environment for macOS Apple Silicon (QEMU with HVF acceleration)
- USB installer tooling (make-usb.sh, patch-grub.sh)
- Starter dotfiles: .gitconfig, .bashrc, .config/starship.toml, .ssh/config
- YAML parsing library (lib/yaml.sh) using Python3/PyYAML
- Test framework with 42 unit tests across 8 test suites
- Smoke test framework for VM-based validation
- Documentation: security model, YubiKey setup, 1Password setup, USB installer, testing
