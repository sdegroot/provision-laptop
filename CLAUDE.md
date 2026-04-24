# Claude Code Instructions

## Workflow

- Always commit changes to the repo after completing work.

## System

- This is a **macOS** system. Use `brew` (Homebrew) for package management.

## Running Provisioning

Use `make` targets or `bin/` scripts directly:

- `make plan` — dry-run, shows what would change
- `make check` — verify current system state against desired state
- `make apply` — apply all modules

To run a single module: `bin/apply --module <name>` (also works with `bin/check` and `bin/plan`).

### Modules (execution order)

directories, taps, host-packages, casks, dotfiles, security, mise, usr-tools, git-projects, containers, mac-defaults

### State files

Module configuration lives in `state/` (e.g., `state/casks.txt`, `state/host-packages.txt`, `state/mac-defaults.conf`). Module scripts live in `lib/modules/<name>/` with `apply.sh`, `check.sh`, and `plan.sh`.
