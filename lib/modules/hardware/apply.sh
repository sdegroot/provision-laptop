#!/usr/bin/env bash
# hardware/apply.sh — Apply hardware configuration.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

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
    iter_hardware_config_files deploy_config_file
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

    # --- Step 1: Create swapfile directory and swapfile ---
    # /var is writable on Silverblue — no subvolume needed.
    # btrfs filesystem mkswapfile handles NOCOW automatically.
    sudo mkdir -p "$(dirname "$SWAPFILE_PATH")"

    local swapfile_expected_bytes
    swapfile_expected_bytes="$(get_swapfile_expected_bytes)"
    local swapfile_needs_creation=0

    if [[ ! -f "$SWAPFILE_PATH" ]]; then
        swapfile_needs_creation=1
    elif [[ "$(get_swapfile_actual_bytes "$SWAPFILE_PATH")" -ne "$swapfile_expected_bytes" ]]; then
        local actual_bytes
        actual_bytes="$(get_swapfile_actual_bytes "$SWAPFILE_PATH")"
        log_info "Swapfile size mismatch: expected ${SWAPFILE_SIZE_GB}GB, got $((actual_bytes / 1024 / 1024 / 1024))GB — recreating"
        sudo swapoff "$SWAPFILE_PATH" 2>/dev/null || true
        sudo rm -f "$SWAPFILE_PATH"
        swapfile_needs_creation=1
    fi

    if [[ "$swapfile_needs_creation" -eq 1 ]]; then
        log_info "Creating swapfile (${SWAPFILE_SIZE_GB}GB)"
        if command -v btrfs &>/dev/null && btrfs filesystem mkswapfile --help &>/dev/null 2>&1; then
            sudo btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE_GB}G" "$SWAPFILE_PATH"
        else
            sudo truncate -s 0 "$SWAPFILE_PATH"
            sudo chattr +C "$SWAPFILE_PATH"
            sudo fallocate -l "${SWAPFILE_SIZE_GB}G" "$SWAPFILE_PATH"
            sudo chmod 600 "$SWAPFILE_PATH"
            sudo mkswap "$SWAPFILE_PATH"
        fi
        sudo swapon "$SWAPFILE_PATH"
        changes_made=1
    fi

    # --- Step 2: Ensure swapfile is in fstab ---
    if ! grep -q "$SWAPFILE_PATH" /etc/fstab 2>/dev/null; then
        log_info "Adding swapfile to fstab"
        echo "${SWAPFILE_PATH} none swap defaults,nofail 0 0" \
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
            resume_offset="$(sudo filefrag -v "$SWAPFILE_PATH" 2>/dev/null | awk 'NR==4{print $4}' | sed 's/\.\.//' || true)"
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
        new_offset="$(sudo filefrag -v "$SWAPFILE_PATH" 2>/dev/null | awk 'NR==4{print $4}' | sed 's/\.\.//' || true)"
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

    if ! systemctl is-enabled --quiet i8042-resume-rescan.service 2>/dev/null; then
        log_info "Enabling i8042-resume-rescan.service"
        sudo systemctl enable i8042-resume-rescan.service
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
# 6. Hostname
# -------------------------------------------------------------------------

apply_hostname() {
    if [[ -n "${PROVISION_ROOT:-}" ]]; then
        return 0
    fi

    local hostname_file
    hostname_file="$(state_file_path "hostname.txt")"
    [[ -f "$hostname_file" ]] || return 0

    local desired
    desired="$(head -1 "$hostname_file" | tr -d '[:space:]')"
    [[ -n "$desired" ]] || return 0

    local current
    current="$(hostnamectl hostname 2>/dev/null || hostname)"

    if [[ "$current" != "$desired" ]]; then
        log_info "Setting hostname: ${current} -> ${desired}"
        sudo hostnamectl set-hostname "$desired"
        changes_made=1
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
apply_hostname

if [[ $changes_made -eq 0 ]]; then
    log_ok "All hardware configuration already correct"
else
    log_ok "Hardware configuration applied (reboot may be required)"
fi
