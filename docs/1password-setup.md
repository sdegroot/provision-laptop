# 1Password Setup

**For context on how 1Password fits with YubiKey and fingerprint, see [Authentication & Security Architecture](authentication-security.md).**

## Installation

1Password is installed as a native RPM package via rpm-ostree. The Flatpak version
is **not used** because it cannot expose the SSH agent socket or browser integration
due to sandbox restrictions.

The provisioning system handles:

1. Adding the 1Password RPM repository (`state/repos.d/1password.repo`)
2. Layering the `1password` package via rpm-ostree (`state/host-packages.txt`)
3. Configuring `SSH_AUTH_SOCK` to point to the 1Password agent (dotfiles)
4. Configuring `~/.ssh/config` to use the agent socket (dotfiles)

```bash
bin/apply
```

A reboot is required after the initial rpm-ostree install.

## SSH Agent

After installation:

1. Open 1Password → Settings → Developer
2. Enable "Use the SSH agent"
3. Enable "Integrate with 1Password CLI"

The agent socket will appear at `~/.1password/agent.sock`. Both `~/.ssh/config`
and `SSH_AUTH_SOCK` are preconfigured by the provisioning system.

## Browser Integration

The native RPM package supports browser integration out of the box. Install the
1Password browser extension in Firefox or Brave and it will detect the native app
automatically.

## Verification

```bash
# Check SSH agent is working
ssh-add -l

# Check the socket exists
ls -la ~/.1password/agent.sock

# Test GitHub SSH
ssh -T git@github.com
```

## Security Notes

- 1Password vault is encrypted locally
- SSH keys never leave 1Password
- Biometric unlock supported (fingerprint if available)
- Lock timeout configurable in 1Password settings
