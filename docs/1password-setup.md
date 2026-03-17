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
5. Git commit/tag signing via `op-ssh-sign` (dotfiles)
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

All commits and tags are signed via SSH using `op-ssh-sign`. The signing key
(public) is configured in `.gitconfig`. To verify signing works:

```bash
# Make a test commit — should not prompt if "Allow when unlocked" is set
echo test > /tmp/test && cd /tmp && git init test-sign && cd test-sign && git commit --allow-empty -m "test"

# Verify signature
git log --show-signature -1
```

Add the same public key to GitHub as a **signing key** (separate from the
authentication key):

```bash
gh ssh-key add ~/.ssh/id_rsa.pub --type signing
# Or copy from: git config user.signingkey
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
- SSH keys never leave 1Password
- Biometric unlock supported (fingerprint if available)
- Lock timeout configurable in 1Password settings
