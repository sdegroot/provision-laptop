#!/usr/bin/env bash
# hardware/check.sh — Verify hardware configuration matches desired state.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

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

check_config_files() {
    local hardware_dir="${PROVISION_DIR}/hardware"
    local effective_root="${PROVISION_ROOT:-}"

    # modprobe configs -> /etc/modprobe.d/
    for src in "${hardware_dir}"/modprobe/*.conf; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/modprobe.d/$(basename "$src")"
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
            log_ok "Config: /etc/modprobe.d/$(basename "$src")"
        else
            log_error "Config drift: /etc/modprobe.d/$(basename "$src")"
            drift_found=1
        fi
    done

    # sysctl configs -> /etc/sysctl.d/
    for src in "${hardware_dir}"/sysctl/*.conf; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/sysctl.d/$(basename "$src")"
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
            log_ok "Config: /etc/sysctl.d/$(basename "$src")"
        else
            log_error "Config drift: /etc/sysctl.d/$(basename "$src")"
            drift_found=1
        fi
    done

    # dracut configs -> /etc/dracut.conf.d/
    for src in "${hardware_dir}"/dracut/*.conf; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/dracut.conf.d/$(basename "$src")"
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
            log_ok "Config: /etc/dracut.conf.d/$(basename "$src")"
        else
            log_error "Config drift: /etc/dracut.conf.d/$(basename "$src")"
            drift_found=1
        fi
    done

    # systemd units -> /etc/systemd/system/
    for src in "${hardware_dir}"/systemd/*.service "${hardware_dir}"/systemd/*.timer; do
        [[ -f "$src" ]] || continue
        local basename_src
        basename_src="$(basename "$src")"
        # sleep.conf goes to sleep.conf.d/
        if [[ "$basename_src" == "sleep.conf" ]]; then
            local dest="${effective_root}/etc/systemd/sleep.conf.d/${basename_src}"
        else
            local dest="${effective_root}/etc/systemd/system/${basename_src}"
        fi
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
            log_ok "Config: ${dest#"${effective_root}"}"
        else
            log_error "Config drift: ${dest#"${effective_root}"}"
            drift_found=1
        fi
    done
}

# -------------------------------------------------------------------------
# 3. Swap / hibernate
# -------------------------------------------------------------------------

check_hibernate() {
    local effective_root="${PROVISION_ROOT:-}"

    if [[ -n "$effective_root" ]]; then
        # In test mode, check for the marker directory and fstab entries
        if [[ -d "${effective_root}/swap" ]]; then
            log_ok "Swap subvolume exists"
        else
            log_error "Missing swap subvolume at /swap"
            drift_found=1
        fi

        local fstab="${effective_root}/etc/fstab"
        if [[ -f "$fstab" ]]; then
            if grep -q '/swap.*btrfs.*subvol=swap' "$fstab" 2>/dev/null; then
                log_ok "Fstab: /swap subvolume mount entry"
            else
                log_error "Missing fstab entry for /swap subvolume mount"
                drift_found=1
            fi
            if grep -q '/swap/swapfile.*x-systemd.requires=swap.mount' "$fstab" 2>/dev/null; then
                log_ok "Fstab: swapfile entry with mount ordering"
            else
                log_error "Missing or incorrect fstab entry for /swap/swapfile"
                drift_found=1
            fi
        fi
    else
        if findmnt /swap &>/dev/null || [[ -f /swap/swapfile ]]; then
            log_ok "Swap subvolume/swapfile exists"
        else
            log_error "Missing swap subvolume or swapfile at /swap"
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
