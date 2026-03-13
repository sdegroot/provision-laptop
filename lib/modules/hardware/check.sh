#!/usr/bin/env bash
# hardware/check.sh — Verify hardware configuration matches desired state.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

drift_found=0

# -------------------------------------------------------------------------
# 1. Kernel parameters
# -------------------------------------------------------------------------

check_kernel_params() {
    local state_file
    state_file="$(state_file_path "kernel-params.txt")"

    if ! is_silverblue; then
        log_warn "Not on Silverblue — skipping kernel param check"
        return 0
    fi

    local current_kargs
    current_kargs="$(rpm-ostree kargs 2>/dev/null || true)"

    while IFS= read -r param; do
        if echo "$current_kargs" | grep -q "$param"; then
            log_ok "Kernel param: ${param}"
        else
            log_error "Missing kernel param: ${param}"
            drift_found=1
        fi
    done < <(parse_state_file "$state_file")
}

# -------------------------------------------------------------------------
# 2. Hardware config files
# -------------------------------------------------------------------------

_check_single_config() {
    local src="$1"
    local dest="$2"
    local effective_root="${PROVISION_ROOT:-}"

    if sudo test -f "$dest" && sudo diff -q "$src" "$dest" &>/dev/null; then
        log_ok "Config: ${dest#"${effective_root}"}"
    else
        log_error "Config drift: ${dest#"${effective_root}"}"
        drift_found=1
    fi
}

check_config_files() {
    iter_hardware_config_files _check_single_config
}

# -------------------------------------------------------------------------
# 3. Swap / hibernate
# -------------------------------------------------------------------------

check_hibernate() {
    local effective_root="${PROVISION_ROOT:-}"
    local swapfile="${effective_root}${SWAPFILE_PATH}"

    # Check swapfile exists
    if [[ -f "$swapfile" ]]; then
        log_ok "Swapfile exists"

        # Verify size
        local actual_bytes expected_bytes
        actual_bytes="$(get_swapfile_actual_bytes "$swapfile")"
        expected_bytes="$(get_swapfile_expected_bytes)"
        if [[ "$actual_bytes" -ne "$expected_bytes" ]]; then
            log_error "Swapfile size mismatch: expected ${SWAPFILE_SIZE_GB}GB, got $((actual_bytes / 1024 / 1024 / 1024))GB"
            drift_found=1
        else
            log_ok "Swapfile size: ${SWAPFILE_SIZE_GB}GB"
        fi
    else
        log_error "Missing swapfile at ${SWAPFILE_PATH}"
        drift_found=1
    fi

    # Check fstab entry
    local fstab="${effective_root}/etc/fstab"
    if [[ -f "$fstab" ]]; then
        if grep -q "${SWAPFILE_PATH}" "$fstab" 2>/dev/null; then
            log_ok "Fstab: swapfile entry"
        else
            log_error "Missing fstab entry for ${SWAPFILE_PATH}"
            drift_found=1
        fi
    fi
}

# -------------------------------------------------------------------------
# 4. Systemd timers
# -------------------------------------------------------------------------

check_timers() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        log_warn "Skipping timer check in test mode"
        return 0
    fi

    if systemctl is-active --quiet btrfs-scrub@-.timer 2>/dev/null; then
        log_ok "Timer active: btrfs-scrub@-.timer"
    else
        log_error "Timer inactive: btrfs-scrub@-.timer"
        drift_found=1
    fi

    if systemctl is-enabled --quiet i8042-resume-rescan.service 2>/dev/null; then
        log_ok "Service enabled: i8042-resume-rescan.service"
    else
        log_error "Service not enabled: i8042-resume-rescan.service"
        drift_found=1
    fi
}

# -------------------------------------------------------------------------
# 5. LUKS FIDO2
# -------------------------------------------------------------------------

check_luks_fido2() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        return 0
    fi

    local crypttab="/etc/crypttab"
    [[ -f "$crypttab" ]] || return 0

    if sudo grep -q 'fido2-device=auto' "$crypttab"; then
        log_ok "Crypttab has fido2-device=auto"
    else
        log_error "Crypttab missing fido2-device=auto"
        drift_found=1
    fi

    if rpm-ostree initramfs 2>/dev/null | grep -q "enabled"; then
        log_ok "Initramfs regeneration enabled"
    else
        log_error "Initramfs regeneration not enabled (needed for FIDO2 at boot)"
        drift_found=1
    fi

    # Check if any LUKS partition has a FIDO2 token enrolled
    local has_fido2=0
    while IFS= read -r luks_dev; do
        if sudo cryptsetup luksDump "$luks_dev" 2>/dev/null | grep -q "fido2"; then
            has_fido2=1
        fi
    done < <(lsblk -nrpo NAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1}')

    if [[ $has_fido2 -eq 1 ]]; then
        log_ok "FIDO2 token enrolled on LUKS partition(s)"
    else
        log_warn "No FIDO2 token enrolled on any LUKS partition — run manually:"
        log_warn "  sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p3"
        log_warn "  sudo systemd-cryptenroll --fido2-device=auto /dev/nvme1n1p1"
    fi
}

# -------------------------------------------------------------------------
# 6. Hostname
# -------------------------------------------------------------------------

check_hostname() {
    local hostname_file
    hostname_file="$(state_file_path "hostname.txt")"
    [[ -f "$hostname_file" ]] || return 0

    local desired
    desired="$(head -1 "$hostname_file" | tr -d '[:space:]')"
    [[ -n "$desired" ]] || return 0

    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        log_warn "Skipping hostname check in test mode"
        return 0
    fi

    local current
    current="$(hostnamectl hostname 2>/dev/null || hostname)"

    if [[ "$current" == "$desired" ]]; then
        log_ok "Hostname: ${desired}"
    else
        log_error "Hostname is '${current}' (expected '${desired}')"
        drift_found=1
    fi
}

# -------------------------------------------------------------------------
# Run all checks
# -------------------------------------------------------------------------

check_kernel_params
check_config_files
check_hibernate
check_timers
check_luks_fido2
check_hostname

if [[ $drift_found -eq 0 ]]; then
    log_ok "All hardware configuration matches desired state"
fi

exit $drift_found
