# Authentication & Security Architecture

How YubiKey, 1Password, and Touch ID work together to provide layered security on macOS.

## Three-layer model

| Layer | Component | Purpose | Authentication |
|-------|-----------|---------|----------------|
| **Hardware security** | YubiKey | Hardware-backed SSH keys, 2FA | Physical key + tap |
| **Vault & secrets** | 1Password | SSH keys, passwords, secrets | Master password or Touch ID |
| **Local authentication** | Touch ID | Login, sudo, vault unlock | Biometric |

## Layer 1: Hardware security (YubiKey)

**Use cases**

- SSH to remote servers (FIDO2 SSH key — non-extractable)
- 2FA for online accounts
- Physical second factor for 1Password unlock (optional)

**Threat model**

- Protects against: malware exfiltrating SSH keys, remote credential theft
- Does not protect against: physical theft of an unlocked Mac

**Setup:** [YubiKey Setup](yubikey-setup.md)

## Layer 2: Secret vault (1Password)

**Use cases**

- SSH authentication (via 1Password SSH agent)
- Password autofill in browsers
- API keys, tokens, secrets accessed by `op` CLI
- Backup SSH keys if YubiKey is lost

**Vault security**

- AES-256 encrypted locally
- Master password required to unlock; Touch ID for fast subsequent unlock
- Lock timeout configurable (default: a few minutes idle)

**Setup:** [1Password Setup](1password-setup.md)

## Layer 3: Local authentication (Touch ID)

**Use cases**

- macOS login at the FileVault prompt and lock screen
- `sudo` (when enabled in `/etc/pam.d/sudo` — see notes below)
- 1Password vault unlock
- Approving SSH/signing operations from the 1Password agent

**Properties**

- Not a sole factor — always have password fallback
- Local only — cannot be used remotely
- Falls back to account password automatically

### Enabling Touch ID for sudo (optional)

macOS supports Touch ID for `sudo` via PAM, but it is off by default and the
config file resets on system updates. Enable it persistently with the
`pam_reattach` module via Homebrew:

```bash
brew install pam-reattach
```

Then add this line at the top of `/etc/pam.d/sudo_local` (creating the file if
missing — `sudo_local` is preserved across updates as of macOS 14):

```
auth       sufficient     pam_tid.so
```

Verify with `sudo -k && sudo whoami` — Touch ID prompt should appear.

## Practical workflow

1. **Boot Mac** → FileVault unlock with account password (or Touch ID after first login)
2. **Login screen** → Touch ID
3. **Open 1Password** → Touch ID unlocks the vault
4. **SSH to GitHub** → SSH config points at 1Password agent → 1Password supplies key (Touch ID or always-allow when unlocked)
5. **Sudo** → Touch ID (if `pam_tid.so` enabled), else password

## Failure modes

### YubiKey lost

- Cannot use FIDO2 SSH key → fall back to 1Password SSH key
- Re-enroll a fresh YubiKey when one arrives

### Touch ID sensor fails

- All Touch ID prompts fall back to password
- 1Password unlocks via master password instead
- macOS login prompts for account password

### 1Password vault compromised

- Rotate any SSH keys stored in vault on the relevant servers
- YubiKey FIDO2 key is unaffected (hardware-backed)
- Change 1Password master password and rotate stored secrets

## Best practices

**YubiKey**

- Enroll 2+ keys (one main, one backup, stored separately)
- Use YubiKey FIDO2 SSH keys for high-security servers when possible

**1Password**

- Strong master password — don't rely solely on Touch ID
- Enable lock timeout
- Keep emergency contact / printed recovery code in a safe place

**Touch ID**

- Enroll multiple fingers
- Always keep account password available as fallback
- Don't treat it as more secure than a strong password — it's faster, not harder to bypass

## References

| Setting | Where |
|---|---|
| 1Password SSH agent socket | `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` |
| SSH config | `~/.ssh/config` (`IdentityAgent` directive) |
| Git signing program | `gpg.ssh.program` in `~/.gitconfig` |
| FileVault | System Settings → Privacy & Security → FileVault |
| Touch ID enrollment | System Settings → Touch ID & Password |
| Touch ID for sudo | `/etc/pam.d/sudo_local` |

See: [YubiKey Setup](yubikey-setup.md) · [1Password Setup](1password-setup.md) · [Security Model](security-model.md)
