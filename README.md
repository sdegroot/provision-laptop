# Provision Laptop

Infrastructure-as-Code for provisioning and maintaining a macOS developer laptop.

## Overview

This repository automates declarative desired-state management with idempotent scripts for macOS.

## Quick Start

### Provisioning a new Mac

1. Run the bootstrap script:
   ```bash
   git clone <repo-url> ~/provision-laptop
   ~/provision-laptop/bootstrap/mac.sh
   ```
   This installs Xcode CLI tools, Homebrew, and runs `bin/apply`.

### Managing an existing machine

```bash
bin/check   # Verify system matches desired state
bin/plan    # Show what would change
bin/apply   # Enforce desired state
```

Target a single module:

```bash
bin/check --module host-packages
bin/apply --module casks
```

## Architecture

The system uses a **module-based reconciliation engine**. Each module manages one concern:

| Module | Purpose |
|--------|---------|
| `directories` | Ensure required directories exist |
| `taps` | Homebrew taps (third-party repositories) |
| `host-packages` | Homebrew formulae (CLI tools) |
| `casks` | Homebrew casks (GUI applications) |
| `dotfiles` | Symlink dotfiles into `$HOME` |
| `security` | SSH config, 1Password agent, default shell |
| `mise` | Runtime version manager (Node, Python, Go, Java) |
| `usr-tools` | User-level CLI tools (Claude, opencode) |
| `git-projects` | Clone development repositories |
| `containers` | Podman machine + sandbox containers |
| `mac-defaults` | macOS system preferences via `defaults write` |

Each module has three scripts: `check.sh` (verify state), `apply.sh` (enforce state), `plan.sh` (dry-run).

Execution order is defined in `lib/modules/order.conf`. Taps run before host-packages (taps must be configured before formulae from those taps can be installed).

## Desired State

System state is declared in files under `state/`:

| File | Format | Purpose |
|------|--------|---------|
| `state/directories.txt` | `path:owner:mode` | Directories to create |
| `state/taps.txt` | One tap per line | Homebrew taps |
| `state/host-packages.txt` | One formula per line | Homebrew formulae |
| `state/casks.txt` | One cask per line | Homebrew casks |
| `state/mac-defaults.conf` | `domain key type value` | macOS defaults |
| `state/containers.conf` | `name:context:description` | Podman container definitions |
| `state/git-projects.conf` | `url namespace` | Git repositories to clone |

### Architecture tags

State file entries can be restricted to specific CPU architectures using `[arch]` prefixes:

```
# Included on all architectures
vim

# Only included on Apple Silicon
[arm64] some-arm-tool
```

## Layered Architecture

- **CLI tools** — Homebrew formulae
- **GUI apps** — Homebrew casks
- **Dev environments** — Podman containers
- **Runtimes** — mise (per-project versions)
- **Sandboxes** — Podman (strong isolation)

## AI Sandbox

Run AI coding agents autonomously in isolated Podman containers:

```bash
bin/ai-sandbox --agent claude \
    --project ~/Projects/my-app \
    --prompt "Add input validation to the registration form"
```

The runner creates a git worktree on a dedicated branch, mounts it into a locked-down container (no host secrets, no push access, resource limits), and lets the agent work. You review the branch afterwards and decide to merge or discard.

## License

Private — personal use only.
