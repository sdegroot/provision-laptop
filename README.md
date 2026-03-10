# Provision Laptop

Infrastructure-as-Code for provisioning and maintaining a Fedora Silverblue developer laptop.

## Overview

This repository automates:
- **Day-0 provisioning** — Kickstart-based OS installation with LUKS encryption and Btrfs
- **Day-2 reconciliation** — Declarative desired-state management with idempotent scripts

Target hardware: Tongfang GX4 (AMD Ryzen, RDNA iGPU). Development/testing done in a Fedora Silverblue aarch64 VM on Apple Silicon.

## Quick Start

### Provisioning a new machine

1. Create a bootable USB: `usb/make-usb.sh`
2. Boot from USB — Kickstart automates the install
3. On first boot: `git clone` this repo and run `bin/install`

### Managing an existing machine

```bash
bin/check   # Verify system matches desired state
bin/plan    # Show what would change
bin/apply   # Enforce desired state
```

Target a single module:

```bash
bin/check --module hardware
bin/apply --module repos
```

## Architecture

The system uses a **module-based reconciliation engine**. Each module manages one concern:

| Module | Purpose |
|--------|---------|
| `directories` | Ensure required directories exist |
| `repos` | Third-party RPM repositories (Tuxedo, RPM Fusion, COPR) |
| `host-packages` | rpm-ostree layered packages |
| `flatpaks` | Flatpak applications |
| `dotfiles` | Symlink dotfiles into `$HOME` |
| `security` | SSH config, 1Password agent |
| `hardware` | Kernel params, hardware configs, hibernate, Btrfs maintenance |
| `mise` | Runtime version manager |
| `toolboxes` | Toolbox container profiles |
| `containers` | Podman sandbox containers |

Each module has three scripts: `check.sh` (verify state), `apply.sh` (enforce state), `plan.sh` (dry-run).

Execution order is defined in `lib/modules/order.conf`. Repos run before host-packages (repos must be configured before packages from those repos can be installed).

## Desired State

System state is declared in files under `state/`:

| File | Format | Purpose |
|------|--------|---------|
| `state/directories.txt` | `path:owner:mode` | Directories to create |
| `state/host-packages.txt` | One package per line | rpm-ostree layered packages |
| `state/flatpaks.txt` | One app ID per line | Flatpak applications |
| `state/repos.conf` | `type url-or-name` | Third-party RPM repos |
| `state/kernel-params.txt` | One param per line | Kernel boot parameters |
| `state/toolbox-profiles.yml` | YAML | Toolbox container definitions |
| `state/containers.conf` | Config format | Podman container definitions |

### Architecture tags

State file entries can be restricted to specific CPU architectures using `[arch]` prefixes:

```
# Included on all architectures
vim-enhanced

# Only included on x86_64
[x86_64] tuxedo-drivers

# Only included on aarch64
[aarch64] some-arm-package
```

This allows the same state files to work on both x86_64 (real laptop) and aarch64 (development VM) without failures. See [State File Reference](docs/state-files.md) for details.

## Hardware Configuration

The `hardware` module manages Tongfang GX4 specific optimizations:

| Config | Location | Purpose |
|--------|----------|---------|
| `hardware/modprobe/amdgpu.conf` | `/etc/modprobe.d/` | AMD FreeSync |
| `hardware/modprobe/audio_powersave.conf` | `/etc/modprobe.d/` | Prevent audio pops |
| `hardware/sysctl/99-laptop.conf` | `/etc/sysctl.d/` | inotify watches, TCP BBR |
| `hardware/dracut/fido2.conf` | `/etc/dracut.conf.d/` | YubiKey LUKS unlock |
| `hardware/systemd/btrfs-scrub@.service` | `/etc/systemd/system/` | Btrfs integrity check |
| `hardware/systemd/btrfs-scrub@.timer` | `/etc/systemd/system/` | Monthly scrub schedule |
| `hardware/systemd/sleep.conf` | `/etc/systemd/sleep.conf.d/` | Suspend-then-hibernate |

Kernel parameters are managed via `rpm-ostree kargs` from `state/kernel-params.txt`.

See [Hardware Setup](docs/hardware-setup.md) for details on the Tongfang GX4 optimizations.

## Layered Architecture

Following Fedora Silverblue best practices:

- **Host** — minimal, immutable base (rpm-ostree)
- **GUI apps** — Flatpak (sandboxed)
- **Dev environments** — Toolbox (mutable containers)
- **Runtimes** — mise (per-project versions)
- **Sandboxes** — Podman (strong isolation)

## AI Sandbox

Run AI coding agents autonomously in isolated Podman containers:

```bash
bin/ai-sandbox --agent claude \
    --project ~/Projects/my-app \
    --prompt "Add input validation to the registration form"
```

The runner creates a git worktree on a dedicated branch, mounts it into a locked-down container (no host secrets, no push access, resource limits), and lets the agent work. You review the branch afterwards and decide to merge or discard. Supports Claude Code, Codex, and Gemini CLI.

See [AI Sandbox](docs/ai-sandbox.md) for setup, security model, and examples.

## Testing

```bash
# Fast unit/integration tests (runs on any OS)
make test

# VM-based smoke tests
make vm-start
tests/vm/run-smoke-tests.sh
```

See [Testing](docs/testing.md) for the full testing strategy.

## VM Development

See [tests/vm/README.md](tests/vm/README.md) for setting up a test VM on macOS.

## Documentation

- [Hardware Setup](docs/hardware-setup.md) — Tongfang GX4 hardware optimizations
- [State File Reference](docs/state-files.md) — State file formats and architecture tags
- [Security Model](docs/security-model.md) — Encryption, SSH, firewall, SELinux
- [Authentication & Security Architecture](docs/authentication-security.md) — YubiKey + 1Password + Fingerprint layered model
- [YubiKey Setup](docs/yubikey-setup.md) — LUKS unlock and SSH with YubiKey
- [Fingerprint Setup](docs/fingerprint-setup.md) — Fingerprint enrollment and PAM integration
- [1Password Setup](docs/1password-setup.md) — SSH agent and CLI setup
- [USB Installer](docs/usb-installer.md) — Creating bootable USB drives
- [AI Sandbox](docs/ai-sandbox.md) — Running AI coding agents in isolated containers
- [Testing](docs/testing.md) — Test levels, writing tests, coverage

## License

Private — personal use only.
