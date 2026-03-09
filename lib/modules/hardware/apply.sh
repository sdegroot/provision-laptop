#!/usr/bin/env bash
# hardware/apply.sh — Apply hardware configuration.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_made=0

# -------------------------------------------------------------------------
# 1. Kernel parameters
# -------------------------------------------------------------------------

apply_kernel_params() {
    local state_file
    state_file="$(state_file_path "kernel-params.txt")"

    if ! is_silverblue; then
        log_warn "Not on Silverblue — skipping kernel param apply"
        return 0
    fi

    local current_kargs
    current_kargs="$(rpm-ostree kargs 2>/dev/null || true)"

    while IFS= read -r param; do
        if ! echo "$current_kargs" | grep -q "$param"; then
            log_info "Adding kernel param: ${param}"
            sudo rpm-ostree kargs --append="$param"
            changes_made=1
        fi
    done < <(parse_state_file "$state_file")
}

# -------------------------------------------------------------------------
# 2. Hardware config files
# -------------------------------------------------------------------------

deploy_config_file() {
    local src="$1"
    local dest="$2"

    local dest_dir
    dest_dir="$(dirname "$dest")"

    if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
        return 0
    fi

    log_info "Deploying: ${dest}"
    sudo mkdir -p "$dest_dir"
    sudo cp "$src" "$dest"
    sudo chmod 644 "$dest"
    changes_made=1
}

apply_config_files() {
    local hardware_dir="${PROVISION_DIR}/hardware"
    local effective_root="${PROVISION_ROOT:-}"

    # modprobe configs -> /etc/modprobe.d/
    for src in "${hardware_dir}"/modprobe/*.conf; do
        [[ -f "$src" ]] || continue
        deploy_config_file "$src" "${effective_root}/etc/modprobe.d/$(basename "$src")"
    done

    # sysctl configs -> /etc/sysctl.d/
    for src in "${hardware_dir}"/sysctl/*.conf; do
        [[ -f "$src" ]] || continue
        deploy_config_file "$src" "${effective_root}/etc/sysctl.d/$(basename "$src")"
    done

    # dracut configs -> /etc/dracut.conf.d/
    for src in "${hardware_dir}"/dracut/*.conf; do
        [[ -f "$src" ]] || continue
        deploy_config_file "$src" "${effective_root}/etc/dracut.conf.d/$(basename "$src")"
    done

    # systemd units -> /etc/systemd/system/ (except sleep.conf)
    for src in "${hardware_dir}"/systemd/*.service "${hardware_dir}"/systemd/*.timer; do
        [[ -f "$src" ]] || continue
        deploy_config_file "$src" "${effective_root}/etc/systemd/system/$(basename "$src")"
    done

    # sleep.conf -> /etc/systemd/sleep.conf.d/
    if [[ -f "${hardware_dir}/systemd/sleep.conf" ]]; then
        deploy_config_file "${hardware_dir}/systemd/sleep.conf" \
            "${effective_root}/etc/systemd/sleep.conf.d/sleep.conf"
    fi
}

# -------------------------------------------------------------------------
# 3. Swap / hibernate setup
# -------------------------------------------------------------------------

apply_hibernate() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        log_warn "Skipping hibernate setup in test mode"
        return 0
    fi

    if ! is_silverblue; then
        log_warn "Not on Silverblue — skipping hibernate setup"
        return 0
    fi

    # Create swap subvolume if it doesn't exist
    if ! findmnt /swap &>/dev/null; then
        if command -v btrfs &>/dev/null; then
            log_info "Creating Btrfs swap subvolume"
            sudo btrfs subvolume create /swap 2>/dev/null || true
            sudo chattr +C /swap
            changes_made=1
        fi
    fi

    # Create swapfile if it doesn't exist
    if [[ ! -f /swap/swapfile ]]; then
        log_info "Creating swapfile (8GB)"
        sudo truncate -s 0 /swap/swapfile
        sudo chattr +C /swap/swapfile
        sudo fallocate -l 8G /swap/swapfile
        sudo chmod 600 /swap/swapfile
        sudo mkswap /swap/swapfile
        sudo swapon /swap/swapfile
        # Add to fstab if not present
        if ! grep -q '/swap/swapfile' /etc/fstab; then
            echo '/swap/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab >/dev/null
        fi
        changes_made=1
    fi

    # Add resume kernel params for hibernate
    local current_kargs
    current_kargs="$(rpm-ostree kargs 2>/dev/null || true)"

    if ! echo "$current_kargs" | grep -q "resume="; then
        local swap_uuid
        swap_uuid="$(findmnt -no UUID / 2>/dev/null || true)"
        if [[ -n "$swap_uuid" ]]; then
            local resume_offset
            resume_offset="$(sudo filefrag -v /swap/swapfile 2>/dev/null | awk 'NR==4{print $4}' | sed 's/\.\.//' || true)"
            if [[ -n "$resume_offset" ]]; then
                log_info "Adding hibernate resume kernel params"
                sudo rpm-ostree kargs --append="resume=UUID=${swap_uuid}" \
                    --append="resume_offset=${resume_offset}"
                changes_made=1
            fi
        fi
    fi
}

# -------------------------------------------------------------------------
# 4. Systemd timers
# -------------------------------------------------------------------------

apply_timers() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        log_warn "Skipping timer enable in test mode"
        return 0
    fi

    sudo systemctl daemon-reload

    if ! systemctl is-enabled --quiet btrfs-scrub@-.timer 2>/dev/null; then
        log_info "Enabling btrfs-scrub@-.timer"
        sudo systemctl enable --now btrfs-scrub@-.timer
        changes_made=1
    fi
}

# -------------------------------------------------------------------------
# 5. Apply sysctl
# -------------------------------------------------------------------------

apply_sysctl() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        return 0
    fi

    if [[ $changes_made -gt 0 ]]; then
        log_info "Reloading sysctl settings"
        sudo sysctl --system >/dev/null 2>&1 || true
    fi
}

# -------------------------------------------------------------------------
# Run all steps
# -------------------------------------------------------------------------

apply_kernel_params
apply_config_files
apply_hibernate
apply_timers
apply_sysctl

if [[ $changes_made -eq 0 ]]; then
    log_ok "All hardware configuration already correct"
else
    log_ok "Hardware configuration applied (reboot may be required)"
fi
