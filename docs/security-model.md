# Security Model

## Principles

- **Secure by default** — encryption, firewall, and SELinux enabled out of the box
- **Hardware-backed keys** — SSH keys stored in YubiKey or 1Password, never on disk
- **Minimal host surface** — keep host packages minimal, use Flatpak and Toolbox
- **No secrets in Git** — all sensitive data managed via 1Password or entered manually

## Layers

### Disk Encryption (LUKS2)

- Full disk encryption via LUKS2
- Password set during installation
- Optional YubiKey FIDO2 unlock via `systemd-cryptenroll`

### SSH

- SSH keys managed by 1Password SSH agent
- No private keys stored on disk
- `~/.ssh/config` points to 1Password agent socket
- Hardware-backed keys via YubiKey supported

### Firewall

- `firewalld` enabled by default
- SSH allowed
- All other inbound traffic blocked

### SELinux

- Enforcing mode
- No policy modifications needed for standard workflow

### 1Password

- Desktop app installed via Flatpak
- SSH agent provides key management
- CLI (`op`) available in toolboxes for scripting

## Verification

Run the security module check:

```bash
bin/check --module security
```

This verifies:
- SSH config is correctly symlinked
- SSH directory permissions (700)
- 1Password agent socket is present
- Firewall is active
