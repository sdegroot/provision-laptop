# Provision Laptop

Infrastructure-as-Code for provisioning and maintaining a Fedora Silverblue developer laptop.

## Overview

This repository automates:
- **Day-0 provisioning** — Kickstart-based OS installation with LUKS encryption and Btrfs
- **Day-2 reconciliation** — Declarative desired-state management with idempotent scripts

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

## Architecture

The system uses a **module-based reconciliation engine**. Each module manages one concern:

| Module | Purpose |
|--------|---------|
| `directories` | Ensure required directories exist |
| `host-packages` | rpm-ostree layered packages |
| `flatpaks` | Flatpak applications |
| `dotfiles` | Symlink dotfiles into `$HOME` |
| `security` | SSH config, 1Password agent |
| `mise` | Runtime version manager |
| `toolboxes` | Toolbox container profiles |
| `containers` | Podman sandbox containers |

Each module has three scripts: `check.sh`, `apply.sh`, `plan.sh`.

Execution order is defined in `lib/modules/order.conf`.

## Desired State

System state is declared in files under `state/`:

- `state/directories.txt` — directories to create (`path:owner:mode`)
- `state/host-packages.txt` — rpm-ostree packages (one per line)
- `state/flatpaks.txt` — Flatpak app IDs (one per line)
- `state/toolbox-profiles.yml` — Toolbox container definitions
- `state/containers.conf` — Podman container definitions

## Layered Architecture

Following Fedora Silverblue best practices:

- **Host** — minimal, immutable base (rpm-ostree)
- **GUI apps** — Flatpak (sandboxed)
- **Dev environments** — Toolbox (mutable containers)
- **Runtimes** — mise (per-project versions)
- **Sandboxes** — Podman (strong isolation)

## Testing

```bash
# Fast unit/integration tests (runs on any OS)
tests/run.sh

# VM-based smoke tests
make vm-create
make vm-start
tests/vm/run-smoke-tests.sh
```

## VM Development

See [tests/vm/README.md](tests/vm/README.md) for setting up a test VM on macOS.

## Documentation

- [Security Model](docs/security-model.md)
- [YubiKey Setup](docs/yubikey-setup.md)
- [1Password Setup](docs/1password-setup.md)
- [USB Installer](docs/usb-installer.md)
- [Testing](docs/testing.md)

## License

Private — personal use only.
