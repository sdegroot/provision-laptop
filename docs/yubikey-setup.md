# YubiKey Setup

## Overview

YubiKey provides hardware-backed security for:

- SSH authentication (via 1Password or direct FIDO2)
- Two-factor authentication (TOTP/FIDO2)

**For context on how YubiKey fits with 1Password and Touch ID, see [Authentication & Security Architecture](authentication-security.md).**

## SSH with YubiKey

### Via 1Password (recommended)

1. Store SSH key in 1Password
2. Enable SSH agent in 1Password Settings → Developer
3. The provisioning system configures `~/.ssh/config` to use the 1Password agent

### Direct FIDO2 SSH key

```bash
# Generate a FIDO2 SSH key (requires YubiKey touch)
ssh-keygen -t ed25519-sk -O resident -O verify-required
```

## YubiKey Authenticator

Install the YubiKey Authenticator GUI for configuration (TOTP, FIDO2 PIN, etc.).
This replaces the discontinued YubiKey Manager (Yubico merged the tools in 2025):

```bash
brew install --cask yubico-authenticator
```

The CLI is available as `ykman`:

```bash
brew install ykman
ykman list
ykman info
```

## Troubleshooting

- **YubiKey not detected:** Re-plug the device; check `ykman list`
- **FIDO2 not working:** `fido2-token -L` (from `libfido2`) lists detected devices
- **SSH-sk requires libfido2:** `brew install libfido2`
