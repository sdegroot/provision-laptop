# Secure Boot with MOK Signing

## Overview

By default, Secure Boot is disabled to simplify out-of-tree kernel module loading. This document describes how to enable Secure Boot by setting up Machine Owner Key (MOK) signing for the DKMS modules that the Tongfang GX4 requires.

Two modules need to be signed:
- **`tuxedo-drivers`** — Tuxedo hardware control (fan curves, keyboard backlight, power management)
- **`yt6801-dkms`** — Motorcomm YT6801 Gigabit Ethernet driver (critical for network connectivity)

With Secure Boot enabled and modules signed, the UEFI firmware verifies module signatures at boot time, providing stronger protection against unsigned/modified kernel code.

**Note:** This process is x86_64 only. The aarch64 development VM skips Secure Boot entirely.

## How It Works

### MOK (Machine Owner Key) Signing Flow

```
1. Provision system generates RSA keypair
   ↓
2. DKMS is configured to auto-sign built modules with the key
   ↓
3. MOK public certificate is enrolled in UEFI via mokutil
   ↓
4. On next reboot: UEFI's shim bootloader (MokManager) prompts for enrollment confirmation
   ↓
5. After user confirms: UEFI stores the MOK certificate permanently
   ↓
6. Kernel boots with Secure Boot enabled and verifies module signatures against the MOK certificate
```

### Automated Steps (Provisioning)

When you run `bin/apply --module hardware`:

1. **Generate MOK keypair** — Creates `/etc/mok/mok.key` (600, root-only) and `/etc/mok/mok.cer` (644)
2. **Configure DKMS** — Deploys `/etc/dkms/framework.conf` with signing directives
3. **Update initramfs** — Adds MOK certificate to dracut so the kernel can find it at boot
4. **Queue enrollment** — Calls `mokutil --import` to queue the certificate for enrollment in the next reboot
5. **Rebuild modules** — Re-signs existing DKMS modules with the new key via `dkms autoinstall`

The system prints the one-time enrollment password prominently. **Do not lose this password** — you need it at the MokManager screen on next boot.

### Manual Steps Required (User Interaction)

You must complete these manually because they require physical interaction:

#### Step 1: Enable Secure Boot in BIOS

1. Reboot and enter BIOS (press **Delete** or **F2** at startup)
2. Navigate to **Security** tab
3. Set **Secure Boot** → **Enabled** (change from current Disabled state)
4. Save and Exit (**F10**)

#### Step 2: Confirm MOK Enrollment in MokManager

On the **first reboot after** provisioning (after Secure Boot is enabled):

1. A blue screen titled **"Perform MOK Management"** will appear (the shim MokManager)
2. Select **"Enroll MOK"**
3. Select **"Continue"**
4. When prompted for password, enter the password printed during provisioning
5. Select **"Yes"** to confirm enrollment
6. Select **"Reboot"**

The system will reboot and Secure Boot will be fully active with your MOK certificate enrolled.

## Implementation Plan

### Files to Create

| Source | Destination | Purpose |
|--------|-------------|---------|
| `hardware/dkms/signing.conf` | `/etc/dkms/framework.conf` | DKMS auto-signing configuration |
| `hardware/dracut/mok.conf` | `/etc/dracut.conf.d/mok.conf` | Embed MOK cert in initramfs |

### Files to Modify

| File | Change |
|------|--------|
| `lib/modules/hardware/apply.sh` | Add `apply_mok()` to generate keypair, deploy configs, queue enrollment, rebuild modules |
| `lib/modules/hardware/check.sh` | Add `check_mok()` to verify keypair exists, configs deployed, enrollment status |
| `lib/modules/hardware/plan.sh` | Add `plan_mok()` to show what would change |
| `docs/hardware-setup.md` | Update BIOS section: Secure Boot from "Disabled" to "Enabled" |
| `tests/test_module_hardware.sh` | Add tests for MOK config files and enrollment checks |
| `CHANGELOG.md` | Document under [Unreleased] |

### Implementation Details

#### `hardware/dkms/signing.conf`

```ini
# Automatic MOK signing for DKMS modules
# Deployed to /etc/dkms/framework.conf by hardware module
# Requires Fedora 43+ (DKMS 3.x)

mok_signing_key=/etc/mok/mok.key
mok_certificate=/etc/mok/mok.cer
sign_file=/usr/lib/kernel/sign-file
```

DKMS 3.x (shipped with Fedora 43) will automatically invoke `/usr/lib/kernel/sign-file` after each module build, signing the `.ko` with the key.

#### `hardware/dracut/mok.conf`

```bash
# Include MOK certificate in initramfs
# Kernel needs this to verify signed modules at boot
install_items+=" /etc/mok/mok.cer "
```

#### `apply_mok()` Logic (pseudocode)

```bash
apply_mok() {
    # Skip on aarch64
    [[ "$(uname -m)" != "x86_64" ]] && return 0

    # Skip system calls in test mode
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        # Only deploy config files in test mode
        deploy_config_file hardware/dkms/signing.conf /etc/dkms/framework.conf
        deploy_config_file hardware/dracut/mok.conf /etc/dracut.conf.d/mok.conf
        return 0
    fi

    # Generate keypair if not present
    if [[ ! -f /etc/mok/mok.key ]]; then
        sudo mkdir -p -m 700 /etc/mok
        sudo openssl req -newkey rsa:2048 -nodes \
            -keyout /etc/mok/mok.key \
            -new -x509 -sha256 -days 3650 \
            -subj "/CN=Provision MOK/" \
            -out /etc/mok/mok.cer
        sudo chmod 600 /etc/mok/mok.key
        sudo chmod 644 /etc/mok/mok.cer
        changes_made=1
    fi

    # Deploy configs
    deploy_config_file hardware/dkms/signing.conf /etc/dkms/framework.conf
    deploy_config_file hardware/dracut/mok.conf /etc/dracut.conf.d/mok.conf

    # Queue enrollment if not already enrolled or pending
    if ! sudo mokutil --test-key /etc/mok/mok.cer 2>/dev/null; then
        if ! sudo mokutil --list-new 2>/dev/null | grep -q "Provision MOK"; then
            # Generate random password for this enrollment
            local pw
            pw="$(openssl rand -base64 18)"

            # Import with password (stdin mode requires password twice)
            printf '%s\n%s\n' "$pw" "$pw" | sudo mokutil --import /etc/mok/mok.cer --stdin

            log_warn "MOK enrollment queued."
            log_warn "Reboot and enter password: ${pw}"
            log_warn "At the blue MokManager screen, select 'Enroll MOK' and confirm."

            changes_made=1
        else
            log_warn "MOK enrollment already queued, waiting for reboot confirmation"
        fi
    fi

    # Rebuild DKMS modules if changes were made
    if [[ $changes_made -eq 1 ]]; then
        sudo dkms autoinstall || \
            log_warn "dkms autoinstall failed — rebuild manually: sudo dkms autoinstall"
    fi
}
```

#### `check_mok()` Logic

Verifies:
1. Keypair exists (`/etc/mok/mok.key` mode 600, `/etc/mok/mok.cer` mode 644)
2. DKMS config deployed correctly
3. Dracut config deployed correctly
4. MOK enrolled in UEFI (via `mokutil --test-key`)
   - Exit 0 = enrolled ✓
   - Appears in `mokutil --list-new` = pending reboot (warn)
   - Neither = not enrolled (error)

Exits 1 if any check fails, 0 if all pass.

#### `plan_mok()` Logic

Uses `log_plan` to show what would change:
- "Would generate MOK keypair at /etc/mok/"
- "Would deploy: /etc/dkms/framework.conf"
- "Would deploy: /etc/dracut.conf.d/mok.conf"
- "Would queue MOK enrollment (reboot required to complete in MokManager)"
- "Would rebuild DKMS modules (dkms autoinstall)"

Always exits 0 (plan is non-destructive).

## Idempotency

The implementation is fully idempotent:

| Scenario | Behavior |
|----------|----------|
| Key already exists | Skip keypair generation, check enrollment status |
| Enrollment already done | Skip `mokutil --import`, confirm enrolled ✓ |
| Enrollment queued | Skip re-import, remind user to reboot |
| Configs already deployed | `diff -q` detects no change, skip copy |
| Run before reboot → run again after reboot | Detects enrollment is now complete, succeeds |
| Test mode (`PROVISION_ROOT` set) | Skip all system calls, only verify config files |

## Verification

After completing both manual steps and rebooting:

```bash
# Check Secure Boot is enabled in firmware
mokutil --sb-state
# Output should be: SecureBoot enabled

# Check MOK is enrolled
mokutil --test-key /etc/mok/mok.cer
# Should exit 0 (no output means success)

# Check modules are signed
modinfo tuxedo_io | grep -i sig
# Should show signature information

# Check kernel accepts signed modules
dmesg | grep -i "tuxedo\|yt6801"
# Should NOT show "module verification failed"

# Verify check passes
bin/check --module hardware
# Should exit 0 with all checks passing
```

## Troubleshooting

### MokManager screen doesn't appear on reboot

**Cause:** Enrollment was not queued (MOK was already enrolled, or `mokutil --import` failed).

**Solution:** Check `mokutil --list-new` to see if queued. If not queued, verify the password was printed during provisioning. Re-run `bin/apply --module hardware` to queue enrollment again.

### "Operation not permitted" when loading tuxedo modules

**Cause:** Modules are not signed, or signature doesn't match enrolled MOK.

**Solution:**
```bash
# Check signature
modinfo tuxedo_io | grep sig

# Check dmesg for details
dmesg | grep "module verification"

# Rebuild and re-sign
sudo dkms autoinstall

# Reboot
sudo reboot
```

### `mokutil` command not found

**Cause:** `mokutil` package not installed (should be auto-installed via `cryptsetup` dependency).

**Solution:**
```bash
sudo dnf install mokutil
```

### "dkms autoinstall failed" warning

**Cause:** DKMS rebuild failed, possibly because `kernel-devel` headers are not installed.

**Solution:**
```bash
# Install kernel development headers
sudo dnf install "kernel-devel-$(uname -r)"

# Rebuild manually
sudo dkms autoinstall
```

## Rotating the MOK Key

If the private key is compromised or you need to rotate it:

1. Delete the old key:
   ```bash
   sudo rm /etc/mok/mok.key /etc/mok/mok.cer
   ```

2. Run provisioning to generate a new one:
   ```bash
   bin/apply --module hardware
   ```

3. Reboot to confirm new enrollment in MokManager (same process as initial enrollment)

4. (Optional) Remove the old key from MOK in BIOS:
   ```bash
   mokutil --delete /path/to/old.cer
   ```

## References

- [shim bootloader documentation](https://github.com/rhboot/shim)
- [mokutil man page](https://linux.die.net/man/1/mokutil)
- [DKMS Secure Boot signing](https://en.opensuse.org/DKMS#DKMS_and_Secure_Boot)
- [Fedora Secure Boot guide](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_Kernel_Modules/#signing-kernel-modules-for-secure-boot_working-with-kernel-modules)
