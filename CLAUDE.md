# Claude Code Instructions

## Workflow

- Always commit changes to the repo after completing work.

## System

- This is a **Fedora Atomic** (immutable) system. Never use `dnf` — it is not available. Use `rpm-ostree` for host package management instead.

## Running Provisioning

Use `make` targets or `bin/` scripts directly:

- `make plan` — dry-run, shows what would change
- `make check` — verify current system state against desired state
- `make apply` — apply all modules

To run a single module: `bin/apply --module <name>` (also works with `bin/check` and `bin/plan`).

### Modules (execution order)

directories, repos, host-packages, flatpaks, dotfiles, security, hardware, mise, usr-tools, git-projects, toolboxes, containers

### State files

Module configuration lives in `state/` (e.g., `state/gnome-extensions.txt`, `state/flatpaks.txt`, `state/host-packages.txt`). Module scripts live in `lib/modules/<name>/` with `apply.sh`, `check.sh`, and `plan.sh`.
