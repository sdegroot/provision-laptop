# State File Reference

State files declare the desired system configuration. They live under `state/` and are read by the provisioning modules.

## Common Syntax

All state files share these rules:
- Lines starting with `#` are comments (ignored)
- Blank lines are ignored
- Leading/trailing whitespace on non-comment lines is preserved

## Architecture Tags

Any state file entry can be restricted to a specific CPU architecture using an `[arch]` prefix:

```
# Included on all architectures
vim-enhanced

# Only on x86_64
[x86_64] tuxedo-drivers

# Only on aarch64
[aarch64] some-arm-package
```

The current architecture is detected via `uname -m`. For testing, override with the `PROVISION_ARCH` environment variable:

```bash
# Parse state file as if running on x86_64
PROVISION_ARCH=x86_64 bin/check --module host-packages
```

This is used to skip x86_64-specific packages (Tuxedo drivers, YT6801 Ethernet) when running in an aarch64 development VM.

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

## `state/host-packages.txt`

**Module:** `host-packages`

rpm-ostree layered packages, one per line. Keep this list minimal — prefer Flatpak and Toolbox over host packages.

```
# Essential tools
vim-enhanced
htop
git

# x86_64-only hardware drivers
[x86_64] tuxedo-drivers
```

## `state/flatpaks.txt`

**Module:** `flatpaks`

Flatpak application IDs, one per line. Installed from Flathub.

```
org.mozilla.firefox
com.visualstudio.code
org.signal.Signal
```

## `state/repos.conf`

**Module:** `repos`

Third-party RPM repository definitions. Format: `type url-or-name`

Supported types:

| Type | Argument | How it's installed |
|------|----------|-------------------|
| `repofile` | URL to `.repo` file | Downloaded to `/etc/yum.repos.d/` via curl |
| `rpmfusion-free` | _(none)_ | Release RPM installed via rpm-ostree |
| `rpmfusion-nonfree` | _(none)_ | Release RPM installed via rpm-ostree |
| `copr` | `owner/project` | `.repo` file downloaded from COPR API |

Example:

```
[x86_64] repofile https://rpm.tuxedocomputers.com/fedora/tuxedo.repo
rpmfusion-free
rpmfusion-nonfree
[x86_64] copr nuzar/yt6801-dkms
```

Note: Silverblue does not ship `dnf`. The repos module uses `curl` and `rpm-ostree` directly.

## `state/kernel-params.txt`

**Module:** `hardware`

Kernel boot parameters, one per line. Applied via `rpm-ostree kargs --append`.

```
amd_pstate=active
nowatchdog
nmi_watchdog=0
```

Verify active parameters: `cat /proc/cmdline`

## `state/toolbox-profiles.yml`

**Module:** `toolboxes`

YAML definitions of toolbox container profiles. Parsed via Python's PyYAML.

```yaml
profiles:
  dev-base:
    image: registry.fedoraproject.org/fedora-toolbox:43
    packages:
      - gcc
      - make
    setup_script: dev-base.sh
```

## `state/flatpak-overrides.conf`

**Module:** `flatpaks`

Flatpak permission overrides applied with `flatpak override --user`. Format: `app_id permission_type permission_value`

Supported permission types:

| Type | Maps to | Example |
|------|---------|---------|
| `filesystem` | `--filesystem=` | `~/.local/share/mise:ro` |
| `env` | `--env=` | `MY_VAR=value` |

```
# Give IntelliJ access to mise-managed SDKs
com.jetbrains.IntelliJ-IDEA-Ultimate filesystem ~/.local/share/mise:ro
com.jetbrains.IntelliJ-IDEA-Ultimate filesystem ~/.jdks:ro
```

This is used to give Flatpak applications access to directories they need but can't see due to sandboxing. IntelliJ needs access to mise-managed SDKs for auto-discovery.

## `state/containers.conf`

**Module:** `containers`

Podman container definitions for sandbox environments.

## Adding New Entries

1. Edit the relevant state file
2. Run `bin/plan` to preview changes
3. Run `bin/apply` to enforce
4. Run `bin/check` to verify

For arch-specific entries, add the `[arch]` prefix and test with `PROVISION_ARCH`:

```bash
# Verify it parses correctly for both architectures
PROVISION_ARCH=x86_64 bin/plan --module host-packages
PROVISION_ARCH=aarch64 bin/plan --module host-packages
```
