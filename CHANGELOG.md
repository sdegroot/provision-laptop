# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
