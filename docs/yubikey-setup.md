# YubiKey Setup

## Overview

YubiKey provides hardware-backed security for:
- SSH authentication (via 1Password or direct FIDO2)
- LUKS disk unlock (via FIDO2)
- Two-factor authentication (TOTP/FIDO2)

**For context on how YubiKey fits with 1Password and fingerprint, see [Authentication & Security Architecture](authentication-security.md).**

## SSH with YubiKey

### Via 1Password (recommended)

1. Store SSH key in 1Password
2. Enable SSH agent in 1Password settings
3. The provisioning system configures `~/.ssh/config` to use the 1Password agent

### Direct FIDO2 SSH Key

```bash
# Generate a FIDO2 SSH key (requires YubiKey touch)
ssh-keygen -t ed25519-sk -O resident -O verify-required
```

## LUKS Unlock with YubiKey

Enroll your YubiKey for disk unlock:

```bash
# Find your LUKS partition
lsblk

# Enroll FIDO2 device
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p3

# Test by rebooting — you should be prompted to touch YubiKey
```

**Note:** Keep your LUKS passphrase as a backup. YubiKey unlock is a convenience,
not a replacement for the passphrase.

## Troubleshooting

- **YubiKey not detected:** Ensure `pcscd` service is running
- **FIDO2 not working:** Check `fido2-token -L` for device detection
- **After firmware update:** Re-enroll the key with `systemd-cryptenroll`
