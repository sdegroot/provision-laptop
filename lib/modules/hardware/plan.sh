#!/usr/bin/env bash
# hardware/plan.sh — Show planned hardware configuration changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

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

_plan_single_config() {
    local src="$1"
    local dest="$2"
    local effective_root="${PROVISION_ROOT:-}"

    if [[ ! -f "$dest" ]] || ! diff -q "$src" "$dest" &>/dev/null; then
        log_plan "Would deploy: ${dest#"${effective_root}"}"
        changes_planned=1
    fi
}

plan_config_files() {
    iter_hardware_config_files _plan_single_config
}

# -------------------------------------------------------------------------
# 3. Swap / hibernate
# -------------------------------------------------------------------------

plan_hibernate() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        return 0
    fi

    if [[ ! -f "$SWAPFILE_PATH" ]]; then
        log_plan "Would create ${SWAPFILE_SIZE_GB}GB swapfile at ${SWAPFILE_PATH}"
        changes_planned=1
    elif [[ "$(get_swapfile_actual_bytes "$SWAPFILE_PATH")" -ne "$(get_swapfile_expected_bytes)" ]]; then
        local actual_bytes
        actual_bytes="$(get_swapfile_actual_bytes "$SWAPFILE_PATH")"
        log_plan "Would recreate swapfile at ${SWAPFILE_SIZE_GB}GB (currently $((actual_bytes / 1024 / 1024 / 1024))GB)"
        changes_planned=1
    fi

    if ! grep -q "$SWAPFILE_PATH" /etc/fstab 2>/dev/null; then
        log_plan "Would add swapfile to fstab"
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

    if ! systemctl is-enabled --quiet i8042-resume-rescan.service 2>/dev/null; then
        log_plan "Would enable i8042-resume-rescan.service"
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
