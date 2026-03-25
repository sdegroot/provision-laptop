# 1Password Setup

**For context on how 1Password fits with YubiKey and fingerprint, see [Authentication & Security Architecture](authentication-security.md).**

## Installation

1Password is installed as a native RPM package via rpm-ostree. The Flatpak version
is **not used** because it cannot expose the SSH agent socket or browser integration
due to sandbox restrictions.

The provisioning system handles:

1. Adding the 1Password RPM repository (`state/repos.d/1password.repo`)
2. Layering `1password` and `1password-cli` via rpm-ostree
3. Configuring `SSH_AUTH_SOCK` to point to the 1Password agent (dotfiles)
4. Configuring `~/.ssh/config` to use the agent socket (dotfiles)
5. Git commit/tag signing via `git-ssh-sign` caching wrapper (dotfiles)
6. SSH agent vault config (`~/.config/1Password/ssh/agent.toml`)
7. Browser extension auto-install via managed policies (Firefox + Brave)

```bash
bin/apply
```

A reboot is required after the initial rpm-ostree install.

## Post-install manual steps

After reboot, open 1Password and configure these settings:

1. **Settings → Developer**
   - Enable **"Use the SSH agent"**
   - Enable **"Integrate with 1Password CLI"**
   - Set SSH agent authorization to **"Allow when unlocked"** (avoids prompts on every git commit/ssh)

2. **Settings → Security**
   - Configure lock timeout and biometric unlock to your preference

## SSH Agent

The agent socket will appear at `~/.1password/agent.sock`. Both `~/.ssh/config`
and `SSH_AUTH_SOCK` are preconfigured by the provisioning system.

The agent config (`~/.config/1Password/ssh/agent.toml`) is managed by
provisioning and exposes keys from the `degroot.dev` and `Private` vaults.

## Git Commit Signing

All commits and tags are signed via SSH. To avoid repeated 1Password prompts
(especially painful during rebases), signing uses a caching wrapper instead of
calling `op-ssh-sign` directly.

### How it works

1. Git calls `~/.local/bin/git-ssh-sign` (configured as `gpg.ssh.program`)
2. The wrapper checks a dedicated `ssh-agent` (socket at `$XDG_RUNTIME_DIR/ssh-signing-agent.sock`)
3. **Key cached** → signs instantly via `ssh-keygen`, no prompt
4. **Key not cached** → extracts the private key from 1Password via `op read`
   (one biometric prompt), loads it into the agent with a 1-hour timeout, then signs
5. After the timeout expires, the next commit triggers one prompt again
6. If anything fails, the wrapper falls back to `op-ssh-sign`

The signing agent runs as a systemd user service (`ssh-signing-agent.service`),
started automatically on login.

SSH authentication (push/pull) is **not affected** — it continues to use the
1Password agent socket via `~/.ssh/config`.

### Components

| File | Purpose |
|---|---|
| `dotfiles/.local/bin/git-ssh-sign` | Caching wrapper script |
| `dotfiles/.config/systemd/user/ssh-signing-agent.service` | Dedicated ssh-agent for signing |
| `dotfiles/.gitconfig` | `gpg.ssh.program = ~/.local/bin/git-ssh-sign` |

### Verification

```bash
# First commit after boot — prompts 1Password once
git commit --allow-empty -m "test signing"

# Second commit — should sign instantly, no prompt
git commit --amend --no-edit

# Check the signing agent has the key cached
SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-signing-agent.sock ssh-add -l

# Clear the cache (next commit will prompt again)
SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-signing-agent.sock ssh-add -D
```

### GitHub setup

Add the signing public key to GitHub as a **signing key** (separate from the
authentication key):

```bash
gh ssh-key add ~/.ssh/id_rsa.pub --type signing
# Or copy from: git config user.signingkey
```

## HTTPS Git Credentials

Repositories that use HTTPS (e.g., self-hosted GitLab) authenticate via
`git-credential-1password`, a custom git credential helper that reads
tokens from 1Password via `op read`.

### How it works

1. Git needs credentials for an HTTPS remote
2. Git calls `git-credential-1password get`
3. The helper matches the host against `[credential "https://..."]` blocks
   in `.gitconfig` to find the 1Password item ID, vault, and field
4. It calls `op read` to fetch the token (may prompt for biometric if
   1Password is locked)
5. Returns the username and token to git

### Adding a new host

1. Store the personal access token in 1Password (note the item ID and vault)
2. Add a credential block to `dotfiles/.gitconfig`:

```gitconfig
[credential "https://git.example.com"]
    helper = 1password
    username = myuser
    op-item = <1password-item-id>
    op-vault = <vault-name>
    op-field = credential
```

The `op-item` should be the 1Password item ID (not the name, to avoid
issues with special characters). Find it with `op item list | grep <name>`.
The `op-field` defaults to `credential` if omitted.

### Configured hosts

| Host | Vault | Purpose |
|---|---|---|
| `git.sittard-geleen.nl` | Epistola | GitLab PAT |

### Verification

```bash
# Test credential lookup (should print username + password)
echo -e "protocol=https\nhost=git.sittard-geleen.nl\n" | git credential fill

# Test fetch
git -C ~/scm/sittard-geleen/epistola fetch
```

## Browser Integration

### Extension installation

Browser extensions are auto-installed via managed policies:

- **Firefox (Flatpak)**: enterprise policy deployed via the systemconfig extension point at `/var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/policies/policies.json`
- **Brave**: `/etc/brave/policies/managed/1password.json`

Extensions will appear automatically on first launch after provisioning.

### Flatpak Firefox native messaging

Flatpak Firefox runs in a sandbox that prevents it from discovering the native
`1Password-BrowserSupport` binary on the host. Without native messaging, the
extension shows a login screen instead of connecting to the desktop app.

The provisioning system bridges this gap with three components:

1. **Wrapper script** (`~/.var/app/org.mozilla.firefox/data/bin/1password-browser-support-wrapper.sh`)
   — detects whether it's running inside a Flatpak sandbox. If so, it uses
   `flatpak-spawn --host` to execute the real `1Password-BrowserSupport` binary
   on the host. Outside the sandbox it runs the binary directly.

2. **Native messaging manifest** (`~/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/com.1password.1password.json`)
   — tells Firefox where the wrapper lives and which extension IDs are allowed
   to use it. The `path` field uses the full host path (`$HOME/.var/app/...`),
   which resolves correctly inside the sandbox because the host
   `~/.var/app/org.mozilla.firefox/` is bind-mounted as the sandbox home.

3. **D-Bus access** — Firefox needs `--talk-name=org.freedesktop.Flatpak` to
   use `flatpak-spawn`. This is granted via `flatpak override --user` and
   configured in `state/flatpak-overrides.conf`.

Additionally, 1Password validates the calling process. When BrowserSupport is
launched via `flatpak-spawn --host`, its parent on the host side is
`flatpak-session-helper`. This process must be whitelisted in
`/etc/1password/custom_allowed_browsers` or 1Password will reject the
connection.

#### Source files

| State file | Deployed to |
|---|---|
| `state/1password/custom_allowed_browsers` | `/etc/1password/custom_allowed_browsers` (sudo) |
| `state/1password/1password-browser-support-wrapper.sh` | `~/.var/app/org.mozilla.firefox/data/bin/` |
| `state/1password/com.1password.1password.json` | `~/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/` |

Deployment is handled by `lib/modules/security/apply.sh`.

#### Troubleshooting

If the extension shows a login screen instead of connecting:

1. Check that 1Password desktop app is running
2. Verify `custom_allowed_browsers` is deployed:
   ```bash
   cat /etc/1password/custom_allowed_browsers
   # Should contain: flatpak-session-helper
   ```
3. Verify the D-Bus permission:
   ```bash
   flatpak override --user --show org.mozilla.firefox
   # Should include: org.freedesktop.Flatpak=talk
   ```
4. Verify the native messaging manifest:
   ```bash
   cat ~/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/com.1password.1password.json
   ```
5. Test the wrapper manually from inside the sandbox:
   ```bash
   flatpak run --command=bash org.mozilla.firefox
   ~/.var/app/org.mozilla.firefox/data/bin/1password-browser-support-wrapper.sh --version
   ```
6. Restart both 1Password and Firefox after making changes

### Flatpak Brave native messaging

Flatpak Brave (`com.brave.Browser`) has the same sandbox limitation as Firefox.
The same `flatpak-spawn` mechanism is used with Chrome/Brave-format manifests.

The provisioning system deploys:

1. **Wrapper script** (`~/.var/app/com.brave.Browser/data/bin/1password-browser-support-wrapper.sh`)
   — same script as Firefox, deployed to Brave's sandbox data directory.

2. **Native messaging manifest** (`~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.1password.1password.json`)
   — Chrome-format manifest using `allowed_origins` with the 1Password Chrome
   extension ID (`aeblfdkhhhdcdjpifhhbdiojplfjncoa`).

3. **D-Bus access** — `--talk-name=org.freedesktop.Flatpak` for Brave, configured
   in `state/flatpak-overrides.conf`.

The `custom_allowed_browsers` whitelist and `flatpak-session-helper` mechanism
are shared with Firefox — no additional host-side configuration is needed.

#### Source files

| State file | Deployed to |
|---|---|
| `state/1password/1password-browser-support-wrapper.sh` | `~/.var/app/com.brave.Browser/data/bin/` |
| `state/1password/com.1password.1password.brave.json` | `~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts/` |

#### Troubleshooting

If the 1Password extension in Brave shows a login screen instead of connecting:

1. Check that 1Password desktop app is running
2. Verify the D-Bus permission:
   ```bash
   flatpak override --user --show com.brave.Browser
   # Should include: org.freedesktop.Flatpak=talk
   ```
3. Verify the native messaging manifest:
   ```bash
   cat ~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.1password.1password.json
   ```
4. Test the wrapper manually from inside the sandbox:
   ```bash
   flatpak run --command=bash com.brave.Browser
   ~/.var/app/com.brave.Browser/data/bin/1password-browser-support-wrapper.sh --version
   ```
5. Restart both 1Password and Brave after making changes

## Verification

```bash
# Check SSH agent is working
ssh-add -l

# Check the socket exists
ls -la ~/.1password/agent.sock

# Test GitHub SSH
ssh -T git@github.com

# Test commit signing
git log --show-signature -1

# Check 1Password CLI
op account list
```

## Security Notes

- 1Password vault is encrypted locally
- SSH authentication keys never leave 1Password — every push/pull requires approval
- The signing key is temporarily cached in a local `ssh-agent` (in-memory only,
  on tmpfs) for up to 1 hour. The private key is extracted via `op read`, loaded
  into the agent, and the temporary file is deleted immediately. Signing keys
  only prove commit authorship — they cannot grant access to any server or repo.
- Biometric unlock supported (fingerprint if available)
- Lock timeout configurable in 1Password settings
