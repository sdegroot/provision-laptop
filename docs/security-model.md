# Security Model

**For detailed explanation of how YubiKey, 1Password, and Touch ID work together, see [Authentication & Security Architecture](authentication-security.md).**

## Principles

- **Secure by default** — FileVault encryption and the macOS application firewall enabled
- **Hardware-backed keys** — SSH keys stored in YubiKey or 1Password, never on disk
- **Minimal host surface** — keep host packages minimal; prefer GUI apps via casks
- **No secrets in Git** — all sensitive data managed via 1Password or entered manually

## Layers

### Disk encryption (FileVault)

- FileVault 2 enabled at install time
- Recovery key escrowed via Apple ID or printed/stored offline
- Touch ID can unlock at login once FileVault is up

### SSH

- SSH keys managed by 1Password SSH agent
- No private keys stored on disk
- `~/.ssh/config` points the `IdentityAgent` at the 1Password agent socket
- Hardware-backed keys via YubiKey supported (FIDO2 / `ssh-keygen -t ed25519-sk`)

### Firewall

- macOS Application Firewall enabled (System Settings → Network → Firewall)
- Stealth mode optional
- App-level allow rules configured per app on first connection

### 1Password

- Native desktop app installed via Homebrew Cask
- SSH agent provides key management (see `docs/1password-setup.md`)
- CLI (`op`) available for scripting

## Verification

Run the security module check:

```bash
bin/check --module security
```

This verifies:

- SSH config is correctly symlinked
- SSH directory permissions (700)
- 1Password agent socket is present
- Default shell is zsh
