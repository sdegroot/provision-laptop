# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Daily system health review (`bin/system-health-review`) — collects journal warnings,
  networking, failed services, available upgrades, and security advisories, then analyzes
  with Claude CLI. Runs daily via systemd user timer, presents report via GNOME notification
  and browser-viewable HTML. Includes fallback report when Claude is unavailable.
- eBPF monitoring tools (bcc-tools, bpftrace) for network connection visibility
- **git-projects module** — automatically clones git repositories during provisioning.
  Repos are listed in `state/git-projects.conf` as `<clone-url> <namespace>` pairs;
  target path is `~/scm/<namespace>/<repo>` (repo name extracted from URL). Supports
  GitHub, GitLab, nested GitLab paths, SSH and HTTPS URLs. Clone-only — never pulls
  existing repos to avoid conflicts with in-progress work.

### Changed
- **Replace zinit with system packages and provisioning-time clones** — zinit was
  cloned from GitHub during shell init, which broke terminal startup when the network
  or SSH agent wasn't ready. Replaced with: `zsh-syntax-highlighting` and
  `zsh-autosuggestions` as layered RPMs, and `zsh-completions`,
  `zsh-history-substring-search`, and `fzf-tab` cloned during provisioning into
  `~/.local/share/zsh-plugins/`. The `.zshrc` now sources plugins from fixed paths
  with graceful fallbacks if not yet installed.

### Fixed
- **Terminal broken after reboot — zinit clone failure cascade** — the zinit auto-install
  in `.zshrc` used an HTTPS clone that triggered the misconfigured git credential helper
  (`op-ssh-sign` is a signing program, not a credential helper). This caused the clone
  to fail, zinit never loaded, the shell setup halted before `mise activate`, and tools
  like `claude` disappeared from PATH. Fixed by removing zinit entirely and removing
  the invalid `[credential]` section from `.gitconfig`.

### Changed
- **Refactor: extract shared logic from hardware, repos, and host-packages modules** —
  created per-module `common.sh` files to eliminate duplicated constants, helper
  functions, and config iteration logic across apply/check/plan triplets.
  - `lib/modules/hardware/common.sh`: swapfile constants (`SWAPFILE_PATH`,
    `SWAPFILE_SIZE_GB`), byte-size helpers, and `iter_hardware_config_files()`
    callback-based iterator replacing 5 duplicated directory loops per file.
  - `lib/modules/repos/common.sh`: `repo_exists()` (was duplicated 3x) and
    `check_freeworld_present()` (encapsulates the Python one-liner for checking
    mesa freeworld in rpm-ostree deployments, was duplicated 3x).
  - `lib/common.sh`: `get_layered_packages()` extracts the rpm-ostree JSON
    parsing for layered packages (was duplicated 6x across repos and host-packages).
  - `tests/helpers_hardware.sh`: `setup_hardware_test_env()` and
    `deploy_hardware_configs_to_fake_root()` replace ~20 lines of repeated
    test setup boilerplate per test case.
  - Net reduction: ~280 lines removed with no functional changes.

### Fixed
- **Flatpak "not in the search path" warning during provisioning** — `XDG_DATA_DIRS`
  didn't include `/var/lib/flatpak/exports/share` in the non-interactive provisioning
  shell. Added the path to `XDG_DATA_DIRS` in the flatpaks apply module before any
  `flatpak install` runs. Normal login sessions are unaffected (set via profile.d).
- **hardware check.sh did not verify sleep.conf deployment** — the systemd file
  loop only matched `*.service` and `*.timer` globs, so `sleep.conf` was never
  checked. Refactoring to the shared `iter_hardware_config_files()` iterator
  naturally fixed this by including sleep.conf in the iteration.
- **mesa-vdpau-drivers-freeworld depsolve failure** — removed VDPAU freeworld driver
  from the repos module. VDPAU is an NVIDIA-oriented API not relevant for AMD GPUs;
  VA-API is the correct hardware video API. The VDPAU freeworld package frequently
  lags behind the system mesa version causing depsolve failures that block provisioning.
- **Swap/hibernate setup broken on Silverblue with composefs** — completely rewrote
  `apply_hibernate()`. The old approach created a separate btrfs swap subvolume and
  mounted it at `/swap`, which failed on Fedora 43 for two reasons: (1) composefs
  makes `/` read-only so `mkdir /swap` fails, and (2) `findmnt -no SOURCE /` returns
  `composefs` instead of the btrfs device. Replaced with a much simpler approach:
  create the swapfile directly at `/var/swap/swapfile` — `/var` is writable on
  Silverblue, and `btrfs filesystem mkswapfile` handles NOCOW per-file (no subvolume
  needed). Removed all subvolume creation, raw btrfs mount, subvolume fstab entry,
  and mount ordering dependency logic. Also enforces swapfile size (96GB) — if an
  existing file is the wrong size, it gets recreated and the `resume_offset` kernel
  param is updated.
- **rpm-ostree transaction conflicts during provisioning** — `bin/apply` failed on
  fresh installs because multiple modules called `rpm-ostree` sequentially without
  waiting for prior transactions to complete. Added `wait_for_rpm_ostree()` helper
  that polls for idle state before any rpm-ostree operation (repos mesa override,
  host-packages install, hardware kernel params). Also added `wait_for_kickstart_packages()`
  so `bin/apply` waits for the first-boot `kickstart-packages.service` to finish
  before running modules.

### Removed
- **tuxedo-drivers** — removed `akmod-tuxedo-drivers`, `tuxedo-drivers-kmod-common`,
  `tuxedo-control-center`, the Tuxedo repo (`state/repos.d/tuxedo.repo`), and
  `sdegroot/tuxedo-drivers-kmod` COPR. Diagnostics confirmed tuxedo-drivers is not
  functional on the SKIKK Green 7 (Tongfang GX4, Strix Point): the BIOS does not
  expose the expected Uniwill WMI GUIDs, so all critical modules (`uniwill_wmi`,
  `tuxedo_io`, `tuxedo_nb05_ec`, `tuxedo_nb05_fan_control`) fail with "No such device".
  The platform is managed by `amd_pmf`, `asus_wmi`, and `platform_profile` instead.
  Removing tuxedo-drivers eliminates kernel taint (12288), unnecessary COPR dependency,
  wrong modules loading, and log noise.

### Added
- **S2idle diagnostics documentation** — documented s2idle test results for the SKIKK
  Green 7 (Ryzen AI 9 HX 370): 66.67% hardware sleep residency, known ACPI BIOS bug
  (`\_SB.ACDC.RTAC` missing symbol), LPI constraint warnings for WLAN/Ethernet bridges,
  and workarounds. See `docs/s2idle-diagnostics.md`.
- Updated `docs/hardware-setup.md` with sleep section, SKIKK Green 7 hardware details,
  and `acpica-tools`/`edid-decode`/`libdisplay-info-tools` in the hardware packages table.

### Changed
- **s2idle-debug: use `mise exec` instead of relying on activated shell** — the script
  kept failing because the repo had no `.mise.toml` to declare its Python dependency,
  and the system Python has no pip. Added `.mise.toml` with `python = "3.12"` at repo
  root and rewrote `bin/s2idle-debug` to use `mise exec python --` for all Python
  commands. This works regardless of whether mise is activated in the current shell.

### Fixed
- **Keyboard not working after suspend/resume** — the i8042 PS/2 controller fails
  to reinitialize after S0ix/s2idle resume on AMD laptops (`atkbd serio0: Failed to
  deactivate keyboard` / `Failed to enable keyboard`). Added `i8042.reset=1` kernel
  parameter to force a full controller reset on resume.
- **Swapfile not activating on boot** — the `/swap` Btrfs subvolume had no fstab
  mount entry, so it wasn't mounted when systemd tried to `swapon`. Fixed
  `apply_hibernate()` to: (1) create the swap subvolume by mounting the raw btrfs
  volume (works on Silverblue's immutable root), (2) add a proper fstab mount entry
  for the `/swap` subvolume, (3) add `x-systemd.requires=swap.mount` ordering
  dependency to the swapfile entry so systemd mounts the subvolume first. Also added
  `/swap` subvolume to the kickstart partitioning so future installs have it from
  the start. Uses `btrfs filesystem mkswapfile` when available. Increased
  swapfile from 8GB to 96GB to match RAM size (required for hibernate).
- **Battery drain during sleep** — AMD systems not reaching deepest S0ix sleep state
  (`amd_pmc: Last suspend didn't reach deepest state`) due to Embedded Controller
  wakeups. Added `acpi.ec_no_wakeup=1` kernel parameter.

### Changed
- **Switch tuxedo-drivers from DKMS to kmod build** — the official `tuxedo-drivers`
  package uses DKMS which is incompatible with rpm-ostree's bwrap sandbox
  (`/var/lib/dkms` not writable). Replaced with `tuxedo-drivers-kmod-common` from
  the `gladion136/tuxedo-drivers-kmod` COPR, which provides pre-built kernel modules
  via akmods. `tuxedo-control-center` remains from the official Tuxedo repo.
- **Ship third-party repos locally to avoid F43 GPG subkey bug** — Tuxedo and
  RPM Fusion repos are now shipped as local `.repo` files in `state/repos.d/`
  with `gpgcheck=0`, matching the existing `netbird.repo` pattern. This avoids
  the RPM 6 / libdnf GPG subkey bug (rpm#3954, rpm-ostree#5494) entirely by
  never importing GPG keys that contain subkeys. Removed the runtime
  `rpm_ostree_with_gpg_retry` workaround from `lib/common.sh` since it is no
  longer needed. COPR ghostty is unaffected and remains dynamic.

### Fixed
- **Silent failures in `bin/apply`** — the `set -e` inside the engine subshell
  (`() || exit_code=$?`) is disabled by bash, so command failures were silently
  ignored. Added explicit error handling to each module:
  - **repos**: `curl` and `cp` failures now tracked and exit non-zero; local
    repofiles are re-copied when content differs from system copy (fixes corrupt
    `netbird.repo`)
  - **host-packages**: `rpm-ostree install` exit code checked; fails loudly
    instead of reporting success
  - **flatpaks**: install failures now propagate — module exits non-zero when
    any flatpak fails to install
  - **hardware**: swap/hibernate setup guarded — if `/swap` cannot be created
    (not Btrfs, or creation failed), logs a warning and skips instead of running
    commands against a nonexistent directory
- **Mesa freeworld override attempted on every run** — the check only looked at
  installed packages (`rpm -q`), missing overrides pending in staged deployments.
  Now checks `rpm-ostree status --json` for pending deployments. Both VA-API and
  VDPAU overrides are combined into a single atomic `rpm-ostree` command.
- **`google-noto-fonts` package not found** — `google-noto-fonts` is a source
  package name, not an installable RPM. Changed to `google-noto-sans-fonts`.
- **Mesa freeworld override fails on F43** — `mesa-vdpau-drivers` is not in the
  F43 Silverblue base image, causing the combined override command to fail. Now
  handles each driver independently: overrides when the base package exists,
  installs freeworld directly otherwise.
- **F43 GPG subkey bug blocks rpm-ostree operations** — RPM 6 auto-imports GPG
  subkeys but libdnf re-imports them causing "failed to add subkey" errors on
  third-party repos (Tuxedo, RPM Fusion, etc.). Added `rpm_ostree_with_gpg_retry`
  helper that detects the failure and retries after temporarily disabling
  gpgcheck on third-party repos (rpm#3954, rpm-ostree#5494).

### Removed
- **`power-profiles-daemon`** — replaced by `tuned-ppd` in Fedora 41+, which is
  already in the F43 Silverblue base image and provides the same D-Bus API.

### Removed
- **yt6801-dkms** — Motorcomm YT6801 Ethernet driver COPR and package removed;
  driver is mainline in Fedora 43 kernel

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
