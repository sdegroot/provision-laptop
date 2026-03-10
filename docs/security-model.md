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

## Client Isolation (Future Idea)

When working for multiple clients, you may want full isolation between environments — separate git config, SSH keys, project files, and IDE settings per client. Several approaches were considered:

| Approach | Isolation | Switching speed | Disk cost | IntelliJ support |
|----------|-----------|----------------|-----------|-----------------|
| Different directories | None (shared git/ssh) | Instant | Low | Native |
| Toolboxes | Partial (shared `$HOME`) | Fast | Medium | Limited |
| Dev Containers | Full | Medium | Medium | Native (Gateway) |
| **Different Linux users** | **Full** | **Slow (session switch)** | **High** | **Native** |

### Recommended: Different Linux Users

Create per-client users (e.g. `sdegroot-clienta`, `sdegroot-clientb`). Each gets:

- Separate `$HOME` — `.gitconfig`, `.ssh/`, `.config/`, `.local/`
- Own mise environments, toolbox containers, Flatpak overrides
- OS-level file permission boundary
- Own IntelliJ settings, recent projects, plugins
- Separate Wayland session via GNOME fast user switching

**How to provision:** Run `bin/apply` as each user independently. Flatpaks are installed system-wide, but overrides (`flatpak override --user`) are per-user.

**Trade-offs:**

- Session switching is heavier than switching directories (full GNOME session)
- Disk usage multiplied per user (~2-5 GB for mise runtimes per user)
- Each user needs their own 1Password agent or SSH keys
- No shared clipboard/windows between sessions (separate Wayland compositors)

**Best suited for:** One client per day, where strong isolation matters more than fast switching.

**Not yet implemented.** If needed, the provisioning system could be extended with `--user` support to set up multiple users declaratively.

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
