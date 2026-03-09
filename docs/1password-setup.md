# 1Password Setup

## Installation

1Password is installed as a Flatpak via the provisioning system:

```bash
bin/apply --module flatpaks
```

## SSH Agent

The provisioning system configures SSH to use the 1Password agent:

1. Open 1Password → Settings → Developer
2. Enable "Use the SSH agent"
3. Enable "Integrate with 1Password CLI"
4. The agent socket will be at `~/.1password/agent.sock`

The SSH config (`~/.ssh/config`) is automatically configured to use this socket.

## CLI (`op`)

To use the 1Password CLI in a toolbox:

```bash
# Inside a toolbox
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
# (adjust for Fedora/dnf as needed)
```

## Verification

```bash
# Check SSH agent is working
ssh-add -l

# Check 1Password CLI
op account list
```

## Security Notes

- 1Password vault is encrypted locally
- SSH keys never leave 1Password
- Biometric unlock supported (fingerprint if available)
- Lock timeout configurable in 1Password settings
