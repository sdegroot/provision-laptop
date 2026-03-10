# Fingerprint Reader Setup

The Tongfang GX4 includes an integrated fingerprint reader. This guide covers enrollment and PAM integration for authentication.

**For context on how fingerprint fits with YubiKey and 1Password, see [Authentication & Security Architecture](authentication-security.md).**

## Prerequisites

- `fprintd` and `libfprint` packages installed (auto-installed via provisioning)
- Fingerprint reader detected and working (typically built-in on GX4)

## Verify Hardware Detection

Check if the fingerprint reader is detected:

```bash
# List USB devices (fingerprint reader usually appears here)
lsusb | grep -i fingerprint

# Or check fprintd directly
systemctl status fprintd
sudo fprintd-list $USER
```

If the reader isn't detected, you may need to:
- Check BIOS settings (ensure biometric device is enabled)
- Reboot and retry
- Check kernel logs: `journalctl -xe | grep -i finger`

## Enroll Fingerprints

Enroll your fingerprints for your user:

```bash
# Enroll fingerprints interactively
fprintd-enroll $USER
```

This will prompt you to scan each finger multiple times (typically 3-5 scans per finger for good coverage).

### Enroll Specific Fingers

You can enroll individual fingers:

```bash
fprintd-enroll -f left-thumb $USER
fprintd-enroll -f right-index $USER
# etc.
```

### Verify Enrollment

Check enrolled fingerprints:

```bash
fprintd-list $USER
```

Output shows enrolled fingers:
```
found 2 devices
Device at /net/reactivated/Fprint/Device/0
  has fingerprints enrolled for user sdegroot:
    - right-index-finger
    - right-middle-finger
```

## PAM Integration

Once enrolled, fingerprints can be used for authentication. The PAM configuration may need manual setup depending on your login manager.

### For GNOME/GDL (graphical login)

GNOME should auto-detect fprintd. To enable fingerprint unlock:

1. Open **Settings** → **Users & Accounts**
2. Unlock the account settings (password)
3. Toggle **Fingerprint** on if available

### For `sudo`

Edit `/etc/pam.d/sudo` to add fingerprint auth:

```bash
sudo nano /etc/pam.d/sudo
```

Add this line near the top (after `#%PAM-1.0`):

```
auth      sufficient    pam_fprintd.so
```

Example `/etc/pam.d/sudo` with fingerprint:

```
#%PAM-1.0
auth      sufficient    pam_fprintd.so
auth      include       system-auth
account   include       system-auth
password  include       system-auth
session   include       system-auth
```

Now `sudo` will accept fingerprint as first auth method, falling back to password if it fails.

### For Console/TTY Login

Edit `/etc/pam.d/login`:

```bash
sudo nano /etc/pam.d/login
```

Add fingerprint support (similar to sudo):

```
auth      sufficient    pam_fprintd.so
auth      include       system-auth
...
```

### For Screen Lock/Unlock (systemd user session)

GNOME Keyring and other tools may auto-use fprintd for unlock. Check:

```bash
# Test if fingerprint works for sudo
sudo -v
# Place finger on reader when prompted
```

## Troubleshooting

### Reader not detected

```bash
# Check kernel driver
lsmod | grep -i fprint

# Check dmesg for errors
dmesg | grep -i finger

# Restart fprintd daemon
sudo systemctl restart fprintd
```

### Fingerprint recognition failing

- Ensure fingers are clean and dry
- Try re-enrolling with more scans
- Check lighting conditions
- Some readers struggle in low light

### PAM still prompting for password

- Verify enrollment: `fprintd-list $USER`
- Check PAM config has `pam_fprintd.so` line
- Test directly: `sudo fprintd-verify`
- Check logs: `journalctl -u fprintd -n 50`

### pam_fprintd.so not found

Install the PAM module:

```bash
# Fedora
sudo dnf install fprintd-pam

# Or check if it's provided by fprintd
rpm -ql fprintd | grep pam
```

## Security Considerations

- **Fingerprints are not private keys** — they're biometric identifiers visible in the real world
- Use fingerprints as convenient 2FA (2nd factor after password), not sole authentication
- For critical operations (sudo), require password in addition to fingerprint (use `auth required` instead of `auth sufficient`)
- YubiKey + fingerprint is a stronger combination than fingerprint alone

## Removing Fingerprints

To delete enrolled fingerprints:

```bash
# Delete all fingerprints for your user
fprintd-delete $USER

# Or delete specific finger
fprintd-delete -f right-index $USER
```

## References

- [fprintd documentation](https://fprint.freedesktop.org/)
- [libfprint supported devices](https://fprint.freedesktop.org/supported-devices.html)
- [PAM documentation](https://linux.die.net/man/5/pam.conf)
