# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed
- **KDE Connect flatpak unavailable** — `org.kde.kdeconnect` is not on Flathub (KDE
  Connect needs deep system integration incompatible with Flatpak sandboxing). Replaced
  with `gnome-shell-extension-gsconnect`, a native GNOME Shell extension that implements
  the KDE Connect protocol and pairs with the same Android app.

### Changed
- Moved phone connectivity from Flatpak (`org.kde.kdeconnect`) to host package
  (`gnome-shell-extension-gsconnect`)

### Fixed
- **OEMDRV repo copy failing silently during kickstart** — the `%post` script runs
  inside a chroot at `/mnt/sysroot` where mounting USB partitions fails silently.
  Moved the OEMDRV copy to a `%post --nochroot` section that runs in the real
  installer environment with full device access. Also replaced `|| true` with
  proper error handling and logging to `/root/kickstart-post-nochroot.log`.
- **Unnecessary git package layering** — removed `git` from `kickstart-packages.service`
  since it is already bundled in the Silverblue ostree image.
- **Netbird repo URL broken** — `https://pkgs.netbird.io/yum/netbird.repo` now returns
  an HTML page instead of a `.repo` file. Shipped the repo definition locally in
  `state/repos.d/netbird.repo` and added local file support to the `repofile` type.

### Added
- **Netbird VPN** — multi-account VPN management via `bin/netbird` with 1Password-backed
  setup keys for headless authentication. Supports `up`, `down`, `switch`, `status`, and
  `list` commands for easy switching between accounts
- Netbird RPM repo (`state/repos.conf`) and package (`state/host-packages.txt`)
- Account configuration via `state/netbird-accounts.conf` (maps account names to `op://` references)
- Netbird documentation (`docs/netbird-setup.md`) with setup guide and troubleshooting
- Netbird test suite (26 tests for account parsing, validation, dry-run commands)
- Directory for Netbird config (`~/.config/netbird`)
- **Testcontainers + Podman** — Docker-compatible API via `podman.socket`, `DOCKER_HOST`
  env var in `.bashrc`, and `.testcontainers.properties` with Ryuk disabled
- `podman-compose` package (`state/host-packages.txt`)
- **Zsh with zinit** — `.zshrc` with zinit plugin manager and five plugins:
  zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions,
  zsh-history-substring-search, and fzf-tab
- `fzf` package for fuzzy finding (used by fzf-tab and shell keybindings)
- Security module sets zsh as default login shell via `usermod`
- **Ghostty terminal** — installed via `scottames/ghostty` COPR with config dotfile
  (JetBrains Mono, catppuccin-mocha theme, zsh integration, GTK titlebar-less)

### Fixed
- **USB kickstart not loading on UEFI hardware** — `--skip-mkefiboot` in the
  mkksiso invocation caused the EFI boot image to remain unpatched, so UEFI
  systems booted with the original GRUB config (no `inst.ks` parameter). The
  kickstart was never loaded, explaining why the full graphical installer
  appeared. Fixed by patching the EFI partition's grub.cfg directly on the USB
  drive after dd (mkefiboot requires loop devices unavailable in Podman on macOS).
  Also added `text` mode and `ignoredisk` directives for fully unattended install.
- **Partitioning on ostree** — moved `/work` and `/sandbox` subvolume mount points
  to `/var/work` and `/var/sandbox`. The ostree root filesystem is immutable, so
  arbitrary top-level directories cannot be created during installation.
- **rpm-ostree packages not persisting** — `rpm-ostree install` during Anaconda
  `%post` doesn't persist because the ostree deployment isn't fully active.
  Replaced with a `kickstart-packages.service` one-shot systemd unit that layers
  packages on first boot and reboots into the new deployment.
- **USB installer** — switched from GRUB patching + OEMDRV kickstart to `mkksiso`
  (official Fedora tool). The kickstart is now embedded directly into the ISO before
  writing to USB. Root cause: dracut cannot reliably mount partitions added via
  sgdisk after dd'ing an ISO (non-standard GPT with partition 1 at sector 0).
  OEMDRV partition is still used for the repo bundle (accessed only during `%post`,
  where the full kernel has all filesystem modules loaded).

### Changed
- **Fedora 41 -> 43** — updated all ostree refs, container base images,
  toolbox profiles, ISO download script, and documentation

### Added
- **AI sandbox** — `bin/ai-sandbox` runner for autonomous AI coding agents (Claude Code,
  Codex, Gemini CLI) in isolated Podman containers with git worktree isolation, strict
  security controls (cap-drop, read-only rootfs, resource limits, no host secrets),
  and session logging
- AI sandbox container image with Node.js, Python, Go, and AI CLI tools
- AI sandbox documentation (`docs/ai-sandbox.md`) with security model and usage examples
- AI sandbox test suite (23 tests for arg parsing, validation, command construction)
- Directories for AI sandbox config (`~/.config/ai-sandbox`) and logs
  (`~/.local/share/ai-sandbox/logs`)

### Fixed
- **toolboxes module** — stdin consumption bug where `toolbox create` / `toolbox run`
  consumed the `while read` loop's input, causing only the first toolbox to be created.
  Fixed with `</dev/null` redirects.
- **first-boot.service** — user references changed from `admin` to `sdegroot`
- **flatpaks** — `org.signal.Signal` arch-tagged to `[x86_64]` (no aarch64 build)

### Removed
- `containers/ai-sandbox/run.sh` — replaced by `bin/ai-sandbox`

### Changed
- Container description for ai-sandbox updated to reflect new purpose

### Added
- **repos module** — manage third-party RPM repos (Tuxedo, RPM Fusion, COPR) with
  VA-API freeworld mesa driver override
- **hardware module** — deploy kernel params, modprobe/sysctl/dracut configs,
  systemd units, swap/hibernate setup, and Btrfs scrub timer
- Hardware config files: AMD FreeSync, audio power save, TCP BBR, inotify limits,
  FIDO2 dracut, suspend-then-hibernate, Btrfs scrub timer
- State files: `kernel-params.txt`, `repos.conf`
- Tuxedo drivers, YubiKey packages, lm_sensors, yt6801-dkms to host-packages
- Signal desktop to Flatpak list (x86_64 target)
- Tests for repos and hardware modules (20 new tests)
- Architecture-aware state file parsing with `[arch]` tag syntax
- Documentation: hardware setup, state file reference, updated README and testing docs

### Changed
- Module order updated: repos before host-packages, hardware after security

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
