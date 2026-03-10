# Authentication & Security Architecture

This document explains how YubiKey, 1Password, and fingerprint work together to provide layered security for the laptop.

## Overview: Three-Layer Model

The system uses three complementary authentication methods at different layers:

| Layer | Component | Purpose | Authentication | Risk Level |
|-------|-----------|---------|-----------------|------------|
| **Hardware security** | YubiKey | Remote SSH, disk encryption | Physical key + tap | Lowest |
| **Vault & secrets** | 1Password | SSH keys, passwords, secrets | Master password or biometric | Low |
| **Local authentication** | Fingerprint | Sudo, login, screen unlock | Biometric scan | Medium |

## Security Model

### Layer 1: Hardware Security (YubiKey)

**What it does:**
- Stores SSH keys in tamper-resistant hardware
- Authenticates disk unlock at boot
- Never exposes private keys to the OS

**When it's used:**
- SSH to remote servers (FIDO2 SSH key)
- LUKS disk unlock at boot
- 2FA for critical online accounts

**Threat model:**
- Protects against: malware stealing SSH keys, disk theft, remote SSH compromise
- Does NOT protect against: physical theft of laptop (with attacker knowing passphrase), local post-boot attacks

**Setup:** [YubiKey Setup](yubikey-setup.md)

### Layer 2: Secret Vault (1Password)

**What it does:**
- Stores SSH keys, passwords, and secrets encrypted locally
- Provides SSH agent for seamless SSH authentication
- Acts as backup if YubiKey is lost or unavailable
- Integrates with system biometrics for unlock

**When it's used:**
- SSH authentication (via 1Password SSH agent)
- Password lookup and autofill
- API keys, database credentials, tokens
- 1Password CLI access (`op` command)

**Vault security:**
- Encrypted with AES-256 locally
- Master password required to unlock
- Can use fingerprint for fast unlock (no password required locally)
- Lock timeout configurable (default: 5 minutes idle)

**Setup:** [1Password Setup](1password-setup.md)

### Layer 3: Biometric Authentication (Fingerprint)

**What it does:**
- Provides convenient local authentication
- Unlocks 1Password vault
- Authenticates `sudo` commands
- Unlocks screen after lock

**When it's used:**
- Daily local authentication (faster than password)
- `sudo` commands (2FA: physical device + biometric)
- Screen unlock (convenience + minor security)

**Security properties:**
- **NOT a sole factor** — should always have password as fallback
- **Cannot be used remotely** — local only
- **Revocable** — can't be changed like a password, but can be re-enrolled
- **Biometric collision risk** — very rare, but possible unlike passwords

**Setup:** [Fingerprint Setup](fingerprint-setup.md)

## Practical Workflow

```
1. Power on laptop
   └─ LUKS asks for unlock
      └─ YubiKey FIDO2 device detected
      └─ Physical tap on YubiKey required
      └─ Disk unlocked ✓

2. Fedora Silverblue boots
   └─ Login screen appears
      └─ Fingerprint available (PAM configured)
      └─ Scan finger to login ✓

3. Open 1Password
   └─ Vault is locked
      └─ Fingerprint scan to unlock ✓
      └─ SSH agent ready

4. SSH to GitHub
   └─ SSH config points to 1Password agent
      └─ 1Password supplies SSH key from vault ✓
      └─ Connected to GitHub

5. Run sudo command
   └─ Password prompt appears
      └─ Fingerprint auth available via PAM
      └─ Scan finger to authenticate ✓
      └─ Command executes
```

## Security Comparisons

### SSH Authentication

| Method | Security | Convenience | Recovery |
|--------|----------|-------------|----------|
| **YubiKey FIDO2** (best) | Hardware-backed, non-extractable | Requires physical key + tap | Have backup key enrolled |
| **1Password SSH key** | Vault-encrypted, local-only | Fast via SSH agent | Master password or biometric |
| **Password** (avoid) | No | Requires typing | Reset password |

**Recommendation:** Use YubiKey for primary SSH. Keep 1Password backup key in case YubiKey is lost.

### Local Authentication (sudo/login)

| Method | Security | Convenience |
|--------|----------|-------------|
| **Fingerprint + device** (current) | 2FA: physical + biometric | Very convenient |
| **Password only** | Single factor | OK but slower |
| **Password + YubiKey** | Hardware 2FA | Requires key present |

**Recommendation:** Use fingerprint for daily sudo (fast 2FA). YubiKey can also be configured as PAM auth method if higher security is needed.

### Screen Unlock

| Method | Security | Convenience |
|--------|----------|-------------|
| **Fingerprint** (current) | Biometric | Very fast |
| **Password** | Single factor | Slower |
| **None** | No security | Instant but risky |

**Recommendation:** Fingerprint is reasonable here (convenience + minor security). Screen lock alone doesn't protect data (disk already decrypted), but prevents casual shoulder-surfing.

## Failure Modes & Fallbacks

### If YubiKey is lost

```
1. Cannot unlock LUKS at boot
   └─ Use LUKS passphrase instead
   └─ YubiKey FIDO2 LUKS key becomes invalid

2. Cannot use SSH FIDO2 key
   └─ Use 1Password SSH key instead
   └─ Re-enroll YubiKey FIDO2 for SSH once new key arrives

Action: Enroll new YubiKey, re-run LUKS cryptenroll, update SSH key
```

### If fingerprint sensor fails

```
1. Cannot auth with fingerprint
   └─ Use password instead
   └─ All PAM services fall back to password

2. 1Password vault remains locked
   └─ Use master password to unlock
   └─ SSH agent still works once unlocked

Action: Get hardware repaired or disable fingerprint in PAM config
```

### If 1Password vault is compromised

```
1. SSH keys stored in vault are exposed
   └─ Rotate compromised keys on servers
   └─ YubiKey FIDO2 key remains secure (hardware-backed)

2. Passwords and secrets are exposed
   └─ Change master password
   └─ Change exposed passwords/secrets

Action: Change 1Password master password immediately, rotate secrets
```

## Best Practices

### YubiKey

- ✅ Store and backup safely (not in laptop)
- ✅ Enroll 2+ YubiKeys for LUKS (one main, one backup)
- ✅ Use for SSH if possible (FIDO2 keys are non-extractable)
- ✅ Keep LUKS passphrase written down somewhere secure
- ❌ Don't leave plugged into laptop 24/7 (theft risk)

### 1Password

- ✅ Use strong master password (don't rely only on biometric)
- ✅ Enable lock timeout (force re-auth after idle)
- ✅ Store SSH backup keys in vault
- ✅ Use biometric unlock for convenience
- ✅ Keep emergency contact sheet with master password backup
- ❌ Don't use simple passwords as master password
- ❌ Don't disable lock timeout entirely

### Fingerprint

- ✅ Enroll multiple fingers per hand (backup if one is unavailable)
- ✅ Use as convenient 2FA (not sole factor)
- ✅ Configure for sudo + screen unlock
- ✅ Keep password available as fallback
- ❌ Don't use as only authentication method
- ❌ Don't use for critical systems without password backup
- ❌ Don't assume it's more secure than password (it's not, just faster)

## Configuration Reference

### YubiKey
- **LUKS enrollment:** `sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1pX`
- **SSH key:** `ssh-keygen -t ed25519-sk`
- **Backup:** Keep enrollment PIN and backup codes
- See: [YubiKey Setup](yubikey-setup.md)

### 1Password
- **SSH agent socket:** `~/.1password/agent.sock`
- **Lock timeout:** Settings → Security → Lock vault in background
- **Biometric:** Settings → Security → Biometric unlock
- See: [1Password Setup](1password-setup.md)

### Fingerprint
- **Enrollment:** `fprintd-enroll $USER`
- **PAM config:** `/etc/pam.d/sudo`, `/etc/pam.d/login`
- **Fallback auth:** `auth sufficient pam_fprintd.so` (allows password fallback)
- See: [Fingerprint Setup](fingerprint-setup.md)

## Updating Individual Docs

After reading this architecture guide, refer to specific setup docs:

- **[YubiKey Setup](yubikey-setup.md)** — Enrollment for LUKS + SSH
- **[1Password Setup](1password-setup.md)** — Vault setup + SSH agent config
- **[Fingerprint Setup](fingerprint-setup.md)** — Biometric enrollment + PAM config
- **[Security Model](security-model.md)** — Encryption, firewall, SELinux details

## Summary

| Scenario | Primary | Secondary | Fallback |
|----------|---------|-----------|----------|
| **SSH to server** | YubiKey FIDO2 | 1Password SSH key | Password (not recommended) |
| **Boot laptop** | YubiKey FIDO2 LUKS | LUKS passphrase | Reset disk (data loss) |
| **Unlock 1Password** | Fingerprint | Master password | Reset vault (data loss) |
| **Sudo command** | Fingerprint | Password | Reset sudo (requires root) |
| **Screen unlock** | Fingerprint | Password | Force logout (lose session) |

This multi-layered approach ensures:
- 🔐 **Remote security:** YubiKey hardware protection
- 🔑 **Secret management:** 1Password encrypted vault
- ⚡ **Local convenience:** Fingerprint fast auth
- 🔄 **Redundancy:** Multiple fallback options at each layer
