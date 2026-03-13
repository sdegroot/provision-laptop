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

    # udev rules -> /etc/udev/rules.d/
    for src in "${hardware_dir}"/udev/*.rules; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/udev/rules.d/$(basename "$src")"
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
            log_ok "Config: /etc/udev/rules.d/$(basename "$src")"
        else
            log_error "Config drift: /etc/udev/rules.d/$(basename "$src")"
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
    local swapfile_path="${effective_root}/var/swap/swapfile"
    local swapfile_size_gb=96

    # Check swapfile exists
    if [[ -f "$swapfile_path" ]]; then
        log_ok "Swapfile exists"

        # Verify size
        local actual_bytes expected_bytes
        actual_bytes="$(wc -c < "$swapfile_path" 2>/dev/null | tr -d ' ' || echo 0)"
        expected_bytes=$(( swapfile_size_gb * 1024 * 1024 * 1024 ))
        if [[ "$actual_bytes" -ne "$expected_bytes" ]]; then
            log_error "Swapfile size mismatch: expected ${swapfile_size_gb}GB, got $((actual_bytes / 1024 / 1024 / 1024))GB"
            drift_found=1
        else
            log_ok "Swapfile size: ${swapfile_size_gb}GB"
        fi
    else
        log_error "Missing swapfile at /var/swap/swapfile"
        drift_found=1
    fi

    # Check fstab entry
    local fstab="${effective_root}/etc/fstab"
    if [[ -f "$fstab" ]]; then
        if grep -q '/var/swap/swapfile' "$fstab" 2>/dev/null; then
            log_ok "Fstab: swapfile entry"
        else
            log_error "Missing fstab entry for /var/swap/swapfile"
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
