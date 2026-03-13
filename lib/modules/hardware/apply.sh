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
            wait_for_rpm_ostree
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

    # udev rules -> /etc/udev/rules.d/
    for src in "${hardware_dir}"/udev/*.rules; do
        [[ -f "$src" ]] || continue
        deploy_config_file "$src" "${effective_root}/etc/udev/rules.d/$(basename "$src")"
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
    local swapfile_path="/var/swap/swapfile"
    local swapfile_size_gb=96

    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        log_warn "Skipping hibernate setup in test mode"
        return 0
    fi

    if ! is_silverblue; then
        log_warn "Not on Silverblue — skipping hibernate setup"
        return 0
    fi

    # --- Step 1: Create swapfile directory and swapfile ---
    # /var is writable on Silverblue — no subvolume needed.
    # btrfs filesystem mkswapfile handles NOCOW automatically.
    sudo mkdir -p "$(dirname "$swapfile_path")"

    local swapfile_expected_bytes=$(( swapfile_size_gb * 1024 * 1024 * 1024 ))
    local swapfile_needs_creation=0

    if [[ ! -f "$swapfile_path" ]]; then
        swapfile_needs_creation=1
    elif [[ "$(wc -c < "$swapfile_path" 2>/dev/null | tr -d ' ' || echo 0)" -ne "$swapfile_expected_bytes" ]]; then
        local actual_bytes
        actual_bytes="$(wc -c < "$swapfile_path" 2>/dev/null | tr -d ' ' || echo 0)"
        log_info "Swapfile size mismatch: expected ${swapfile_size_gb}GB, got $((actual_bytes / 1024 / 1024 / 1024))GB — recreating"
        sudo swapoff "$swapfile_path" 2>/dev/null || true
        sudo rm -f "$swapfile_path"
        swapfile_needs_creation=1
    fi

    if [[ "$swapfile_needs_creation" -eq 1 ]]; then
        log_info "Creating swapfile (${swapfile_size_gb}GB)"
        if command -v btrfs &>/dev/null && btrfs filesystem mkswapfile --help &>/dev/null 2>&1; then
            sudo btrfs filesystem mkswapfile --size "${swapfile_size_gb}G" "$swapfile_path"
        else
            sudo truncate -s 0 "$swapfile_path"
            sudo chattr +C "$swapfile_path"
            sudo fallocate -l "${swapfile_size_gb}G" "$swapfile_path"
            sudo chmod 600 "$swapfile_path"
            sudo mkswap "$swapfile_path"
        fi
        sudo swapon "$swapfile_path"
        changes_made=1
    fi

    # --- Step 2: Ensure swapfile is in fstab ---
    if ! grep -q "$swapfile_path" /etc/fstab 2>/dev/null; then
        log_info "Adding swapfile to fstab"
        echo "${swapfile_path} none swap defaults,nofail 0 0" \
            | sudo tee -a /etc/fstab >/dev/null
        changes_made=1
    fi

    # --- Step 3: Add/update resume kernel params for hibernate ---
    local current_kargs
    current_kargs="$(rpm-ostree kargs 2>/dev/null || true)"

    # On composefs (Fedora 43+), the btrfs UUID is on /sysroot, not /
    local root_uuid
    root_uuid="$(findmnt -no UUID /sysroot 2>/dev/null || findmnt -no UUID / 2>/dev/null || true)"

    if ! echo "$current_kargs" | grep -q "resume="; then
        if [[ -n "$root_uuid" ]]; then
            local resume_offset
            resume_offset="$(sudo filefrag -v "$swapfile_path" 2>/dev/null | awk 'NR==4{print $4}' | sed 's/\.\.//' || true)"
            if [[ -n "$resume_offset" ]]; then
                wait_for_rpm_ostree
                log_info "Adding hibernate resume kernel params"
                sudo rpm-ostree kargs --append="resume=UUID=${root_uuid}" \
                    --append="resume_offset=${resume_offset}"
                changes_made=1
            fi
        fi
    elif [[ "$swapfile_needs_creation" -eq 1 ]] && echo "$current_kargs" | grep -q "resume_offset="; then
        # Swapfile was recreated — the physical offset has changed
        local new_offset
        new_offset="$(sudo filefrag -v "$swapfile_path" 2>/dev/null | awk 'NR==4{print $4}' | sed 's/\.\.//' || true)"
        if [[ -n "$new_offset" ]]; then
            local old_offset
            old_offset="$(echo "$current_kargs" | grep -o 'resume_offset=[^ ]*')"
            if [[ "resume_offset=${new_offset}" != "$old_offset" ]]; then
                wait_for_rpm_ostree
                log_info "Updating hibernate resume_offset kernel param"
                sudo rpm-ostree kargs --replace="resume_offset=${new_offset}"
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
