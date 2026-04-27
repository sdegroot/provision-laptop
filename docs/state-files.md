# State File Reference

State files declare the desired system configuration. They live under `state/` and are read by the provisioning modules.

## Common syntax

All state files share these rules:

- Lines starting with `#` are comments (ignored)
- Blank lines are ignored
- Leading/trailing whitespace on non-comment lines is preserved

## Architecture tags

Any state file entry can be restricted to a specific CPU architecture using an `[arch]` prefix:

```
# Included on all architectures
ripgrep

# Only on arm64 (Apple Silicon)
[arm64] some-arm-only-formula

# Only on x86_64 (Intel)
[x86_64] some-intel-only-formula
```

The current architecture is detected via `uname -m`. For testing, override with the `PROVISION_ARCH` environment variable:

```bash
PROVISION_ARCH=x86_64 bin/check --module host-packages
```

## `state/directories.txt`

**Module:** `directories`

Directories to create. Format: `path:owner:mode`

```
~/projects:${USER}:0755
~/bin:${USER}:0700
```

- `~` expands to `$HOME`
- `${USER}` expands to the current user
- Owner defaults to `$USER`, mode defaults to `0755`

## `state/taps.txt`

**Module:** `taps`

Homebrew taps (third-party formula/cask repositories), one per line.

```
homebrew/cask-fonts
hashicorp/tap
```

## `state/host-packages.txt`

**Module:** `host-packages`

Homebrew formulae installed at the host level, one per line.

```
ripgrep
fd
htop
```

## `state/casks.txt`

**Module:** `casks`

Homebrew casks (GUI applications), one per line.

```
1password
1password-cli
ghostty
brave-browser
```

## `state/appstore.txt`

**Module:** `appstore`

Mac App Store apps installed via `mas`. Format: `app-id  # name`

## `state/mac-defaults.conf`

**Module:** `mac-defaults`

macOS system preferences applied via `defaults write`. See the file itself for format and examples.

## `state/git-projects.conf`

**Module:** `git-projects`

Git repos to clone. Format: `clone-url  namespace`

```
git@github.com:org/repo.git  myorg
https://gitlab.com/group/proj.git  internal
```

Repos are cloned to `~/scm/<namespace>/<repo>/`. SSH URLs require the 1Password SSH agent.

## `state/containers.conf`

**Module:** `containers`

Podman container definitions for sandbox environments.

## `state/brave-profiles.conf`

**Module:** `dotfiles`

Brave profile setup (used by browser-chooser launchers).

## `state/dotfiles-seed.txt`

**Module:** `dotfiles`

Seed entries for dotfile bootstrap.

## `state/usr-tools.conf`

**Module:** `usr-tools`

Tools installed under `/usr/local/` (or comparable) outside of Homebrew.

## `state/zsh-plugins.conf`

**Module:** `dotfiles`

Zsh plugins to install (e.g. via clone or Homebrew).

## Adding new entries

1. Edit the relevant state file
2. Run `bin/plan` to preview changes
3. Run `bin/apply` to enforce
4. Run `bin/check` to verify

For arch-specific entries, add the `[arch]` prefix and test with `PROVISION_ARCH`:

```bash
PROVISION_ARCH=x86_64 bin/plan --module host-packages
PROVISION_ARCH=arm64  bin/plan --module host-packages
```
