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

    if ! command -v btrfs &>/dev/null; then
        log_warn "Btrfs not available — skipping swap/hibernate setup"
        return 0
    fi

    # --- Step 1: Ensure swap subvolume exists ---
    # On Silverblue the root is immutable, so we can't just
    # `btrfs subvolume create /swap`. Instead, mount the raw btrfs volume
    # and create the subvolume alongside root/var/containers.
    #
    # On Fedora 43+ with composefs, `/` is a composefs overlay — the real
    # btrfs filesystem is mounted at `/sysroot`. Fall back to `/` for
    # older Fedora versions without composefs.
    if ! findmnt /swap &>/dev/null; then
        local root_dev
        root_dev="$(findmnt -no SOURCE /sysroot 2>/dev/null | sed 's/\[.*\]//')"
        if [[ -z "$root_dev" ]]; then
            root_dev="$(findmnt -no SOURCE / 2>/dev/null | sed 's/\[.*\]//')"
        fi
        if [[ -z "$root_dev" ]]; then
            log_warn "Cannot determine root device — skipping swap/hibernate setup"
            return 0
        fi

        local tmpdir
        tmpdir="$(mktemp -d)"
        if ! sudo mount -t btrfs -o subvol=/ "$root_dev" "$tmpdir" 2>/dev/null; then
            log_warn "Failed to mount btrfs root — skipping swap/hibernate setup"
            rmdir "$tmpdir"
            return 0
        fi

        if [[ ! -d "${tmpdir}/swap" ]]; then
            log_info "Creating Btrfs swap subvolume"
            if ! sudo btrfs subvolume create "${tmpdir}/swap"; then
                log_warn "Failed to create swap subvolume"
                sudo umount "$tmpdir"
                rmdir "$tmpdir"
                return 0
            fi
            changes_made=1
        fi

        sudo umount "$tmpdir"
        rmdir "$tmpdir"
    fi

    # --- Step 2: Ensure /swap subvolume mount is in fstab ---
    if ! grep -q '/swap.*btrfs.*subvol=swap' /etc/fstab 2>/dev/null; then
        local root_uuid
        root_uuid="$(findmnt -no UUID /sysroot 2>/dev/null || true)"
        if [[ -z "$root_uuid" ]]; then
            root_uuid="$(findmnt -no UUID / 2>/dev/null || true)"
        fi
        if [[ -n "$root_uuid" ]]; then
            log_info "Adding /swap subvolume mount to fstab"
            echo "UUID=${root_uuid} /swap btrfs subvol=swap,nodatacow,nofail 0 0" \
                | sudo tee -a /etc/fstab >/dev/null
            changes_made=1
        fi
    fi

    # Mount /swap now if not already mounted
    if ! findmnt /swap &>/dev/null; then
        sudo mkdir -p /swap
        sudo mount /swap || {
            log_warn "Failed to mount /swap — skipping swapfile creation"
            return 0
        }
    fi

    # Verify /swap exists before proceeding
    if [[ ! -d /swap ]]; then
        log_warn "/swap directory does not exist — skipping swapfile creation"
        return 0
    fi

    # --- Step 3: Create or resize swapfile ---
    local swapfile_size_gb=96
    local swapfile_expected_bytes=$(( swapfile_size_gb * 1024 * 1024 * 1024 ))
    local swapfile_needs_creation=0

    if [[ ! -f /swap/swapfile ]]; then
        swapfile_needs_creation=1
    elif [[ "$(wc -c < /swap/swapfile 2>/dev/null | tr -d ' ' || echo 0)" -ne "$swapfile_expected_bytes" ]]; then
        local actual_bytes
        actual_bytes="$(wc -c < /swap/swapfile 2>/dev/null | tr -d ' ' || echo 0)"
        log_info "Swapfile size mismatch: expected ${swapfile_size_gb}GB, got $((actual_bytes / 1024 / 1024 / 1024))GB — recreating"
        sudo swapoff /swap/swapfile 2>/dev/null || true
        sudo rm -f /swap/swapfile
        swapfile_needs_creation=1
    fi

    if [[ "$swapfile_needs_creation" -eq 1 ]]; then
        log_info "Creating swapfile (${swapfile_size_gb}GB)"
        if command -v btrfs &>/dev/null && btrfs filesystem mkswapfile --help &>/dev/null 2>&1; then
            sudo btrfs filesystem mkswapfile --size "${swapfile_size_gb}G" /swap/swapfile
        else
            sudo truncate -s 0 /swap/swapfile
            sudo chattr +C /swap/swapfile
            sudo fallocate -l "${swapfile_size_gb}G" /swap/swapfile
            sudo chmod 600 /swap/swapfile
            sudo mkswap /swap/swapfile
        fi
        sudo swapon /swap/swapfile
        changes_made=1
    fi

    # --- Step 4: Ensure swap entry is in fstab with correct ordering ---
    # The swap entry must depend on the /swap mount via x-systemd.requires
    local swap_fstab_entry='/swap/swapfile none swap defaults,nofail,pri=10,x-systemd.requires=swap.mount 0 0'
    if grep -q '/swap/swapfile' /etc/fstab 2>/dev/null; then
        # Fix existing entry if it lacks the ordering dependency
        if ! grep -q 'x-systemd.requires=swap.mount' /etc/fstab 2>/dev/null; then
            log_info "Fixing swapfile fstab entry with mount ordering dependency"
            sudo sed -i '\|/swap/swapfile|d' /etc/fstab
            echo "$swap_fstab_entry" | sudo tee -a /etc/fstab >/dev/null
            changes_made=1
        fi
    else
        log_info "Adding swapfile to fstab"
        echo "$swap_fstab_entry" | sudo tee -a /etc/fstab >/dev/null
        changes_made=1
    fi

    # --- Step 5: Add/update resume kernel params for hibernate ---
    local current_kargs
    current_kargs="$(rpm-ostree kargs 2>/dev/null || true)"

    if ! echo "$current_kargs" | grep -q "resume="; then
        # For Btrfs swapfile hibernate, resume= takes the UUID of the filesystem
        # containing the swapfile (i.e., root), not a swap partition UUID.
        local root_uuid
        root_uuid="${root_uuid:-$(findmnt -no UUID /sysroot 2>/dev/null || findmnt -no UUID / 2>/dev/null || true)}"
        if [[ -n "$root_uuid" ]]; then
            local resume_offset
            resume_offset="$(sudo filefrag -v /swap/swapfile 2>/dev/null | awk 'NR==4{print $4}' | sed 's/\.\.//' || true)"
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
        new_offset="$(sudo filefrag -v /swap/swapfile 2>/dev/null | awk 'NR==4{print $4}' | sed 's/\.\.//' || true)"
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
