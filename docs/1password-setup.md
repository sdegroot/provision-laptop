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

The native RPM package supports browser integration out of the box. Browser
extensions are auto-installed via managed policies:

- **Firefox**: `/etc/firefox/policies/policies.json`
- **Brave**: `/etc/brave/policies/managed/1password.json`

Extensions will appear automatically on first launch after provisioning.

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
