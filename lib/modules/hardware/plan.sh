#!/usr/bin/env bash
# hardware/plan.sh — Show planned hardware configuration changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_planned=0

# -------------------------------------------------------------------------
# 1. Kernel parameters
# -------------------------------------------------------------------------

plan_kernel_params() {
    local state_file
    state_file="$(state_file_path "kernel-params.txt")"

    if ! is_silverblue; then
        log_warn "Not on Silverblue — skipping kernel param plan"
        return 0
    fi

    local current_kargs
    current_kargs="$(rpm-ostree kargs 2>/dev/null || true)"

    while IFS= read -r param; do
        if ! echo "$current_kargs" | grep -q "$param"; then
            log_plan "Would add kernel param: ${param}"
            changes_planned=1
        fi
    done < <(parse_state_file "$state_file")
}

# -------------------------------------------------------------------------
# 2. Hardware config files
# -------------------------------------------------------------------------

plan_config_files() {
    local hardware_dir="${PROVISION_DIR}/hardware"
    local effective_root="${PROVISION_ROOT:-}"

    for src in "${hardware_dir}"/modprobe/*.conf; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/modprobe.d/$(basename "$src")"
        if [[ ! -f "$dest" ]] || ! diff -q "$src" "$dest" &>/dev/null; then
            log_plan "Would deploy: /etc/modprobe.d/$(basename "$src")"
            changes_planned=1
        fi
    done

    for src in "${hardware_dir}"/sysctl/*.conf; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/sysctl.d/$(basename "$src")"
        if [[ ! -f "$dest" ]] || ! diff -q "$src" "$dest" &>/dev/null; then
            log_plan "Would deploy: /etc/sysctl.d/$(basename "$src")"
            changes_planned=1
        fi
    done

    for src in "${hardware_dir}"/dracut/*.conf; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/dracut.conf.d/$(basename "$src")"
        if [[ ! -f "$dest" ]] || ! diff -q "$src" "$dest" &>/dev/null; then
            log_plan "Would deploy: /etc/dracut.conf.d/$(basename "$src")"
            changes_planned=1
        fi
    done

    for src in "${hardware_dir}"/systemd/*.service "${hardware_dir}"/systemd/*.timer; do
        [[ -f "$src" ]] || continue
        local dest="${effective_root}/etc/systemd/system/$(basename "$src")"
        if [[ ! -f "$dest" ]] || ! diff -q "$src" "$dest" &>/dev/null; then
            log_plan "Would deploy: /etc/systemd/system/$(basename "$src")"
            changes_planned=1
        fi
    done

    if [[ -f "${hardware_dir}/systemd/sleep.conf" ]]; then
        local dest="${effective_root}/etc/systemd/sleep.conf.d/sleep.conf"
        if [[ ! -f "$dest" ]] || ! diff -q "${hardware_dir}/systemd/sleep.conf" "$dest" &>/dev/null; then
            log_plan "Would deploy: /etc/systemd/sleep.conf.d/sleep.conf"
            changes_planned=1
        fi
    fi
}

# -------------------------------------------------------------------------
# 3. Swap / hibernate
# -------------------------------------------------------------------------

plan_hibernate() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        return 0
    fi

    if ! findmnt /swap &>/dev/null; then
        log_plan "Would create Btrfs swap subvolume and mount at /swap"
        changes_planned=1
    fi

    if ! grep -q '/swap.*btrfs.*subvol=swap' /etc/fstab 2>/dev/null; then
        log_plan "Would add /swap subvolume mount to fstab"
        changes_planned=1
    fi

    local swapfile_size_gb=96
    if [[ ! -f /swap/swapfile ]]; then
        log_plan "Would create ${swapfile_size_gb}GB swapfile at /swap/swapfile"
        changes_planned=1
    elif [[ "$(wc -c < /swap/swapfile 2>/dev/null | tr -d ' ' || echo 0)" -ne $(( swapfile_size_gb * 1024 * 1024 * 1024 )) ]]; then
        local actual_bytes
        actual_bytes="$(wc -c < /swap/swapfile 2>/dev/null | tr -d ' ' || echo 0)"
        log_plan "Would recreate swapfile at ${swapfile_size_gb}GB (currently $((actual_bytes / 1024 / 1024 / 1024))GB)"
        changes_planned=1
    fi

    if grep -q '/swap/swapfile' /etc/fstab 2>/dev/null && \
       ! grep -q 'x-systemd.requires=swap.mount' /etc/fstab 2>/dev/null; then
        log_plan "Would fix swapfile fstab entry with mount ordering dependency"
        changes_planned=1
    fi
}

# -------------------------------------------------------------------------
# 4. Systemd timers
# -------------------------------------------------------------------------

plan_timers() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        return 0
    fi

    if ! systemctl is-enabled --quiet btrfs-scrub@-.timer 2>/dev/null; then
        log_plan "Would enable btrfs-scrub@-.timer"
        changes_planned=1
    fi
}

# -------------------------------------------------------------------------
# Run all plans
# -------------------------------------------------------------------------

plan_kernel_params
plan_config_files
plan_hibernate
plan_timers

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No hardware changes needed"
fi
