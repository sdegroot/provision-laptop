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

    if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
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
# Run all checks
# -------------------------------------------------------------------------

check_kernel_params
check_config_files
check_hibernate
check_timers

if [[ $drift_found -eq 0 ]]; then
    log_ok "All hardware configuration matches desired state"
fi

exit $drift_found
