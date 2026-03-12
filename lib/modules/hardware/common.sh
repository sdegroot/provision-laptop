#!/usr/bin/env bash
# hardware/common.sh — Shared constants and helpers for the hardware module.
#
# Sourced by apply.sh, check.sh, and plan.sh. Assumes lib/common.sh is
# already loaded (provides PROVISION_DIR, PROVISION_ROOT, logging, etc.).

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SWAPFILE_PATH="/var/swap/swapfile"
SWAPFILE_SIZE_GB=96

# ---------------------------------------------------------------------------
# Swapfile helpers
# ---------------------------------------------------------------------------

get_swapfile_actual_bytes() {
    local path="${1:-${PROVISION_ROOT:-}${SWAPFILE_PATH}}"
    wc -c < "$path" 2>/dev/null | tr -d ' ' || echo 0
}

get_swapfile_expected_bytes() {
    echo $(( SWAPFILE_SIZE_GB * 1024 * 1024 * 1024 ))
}

# ---------------------------------------------------------------------------
# Config file iteration
# ---------------------------------------------------------------------------

# iter_hardware_config_files <callback>
#   Iterates all hardware config files and calls callback(src, dest) for each.
#   Uses PROVISION_DIR for source paths and PROVISION_ROOT for dest paths.
iter_hardware_config_files() {
    local callback="$1"
    local hardware_dir="${PROVISION_DIR}/hardware"
    local effective_root="${PROVISION_ROOT:-}"

    # modprobe configs -> /etc/modprobe.d/
    for src in "${hardware_dir}"/modprobe/*.conf; do
        [[ -f "$src" ]] || continue
        "$callback" "$src" "${effective_root}/etc/modprobe.d/$(basename "$src")"
    done

    # sysctl configs -> /etc/sysctl.d/
    for src in "${hardware_dir}"/sysctl/*.conf; do
        [[ -f "$src" ]] || continue
        "$callback" "$src" "${effective_root}/etc/sysctl.d/$(basename "$src")"
    done

    # dracut configs -> /etc/dracut.conf.d/
    for src in "${hardware_dir}"/dracut/*.conf; do
        [[ -f "$src" ]] || continue
        "$callback" "$src" "${effective_root}/etc/dracut.conf.d/$(basename "$src")"
    done

    # udev rules -> /etc/udev/rules.d/
    for src in "${hardware_dir}"/udev/*.rules; do
        [[ -f "$src" ]] || continue
        "$callback" "$src" "${effective_root}/etc/udev/rules.d/$(basename "$src")"
    done

    # systemd units -> /etc/systemd/system/
    for src in "${hardware_dir}"/systemd/*.service "${hardware_dir}"/systemd/*.timer; do
        [[ -f "$src" ]] || continue
        "$callback" "$src" "${effective_root}/etc/systemd/system/$(basename "$src")"
    done

    # sleep.conf -> /etc/systemd/sleep.conf.d/
    if [[ -f "${hardware_dir}/systemd/sleep.conf" ]]; then
        "$callback" "${hardware_dir}/systemd/sleep.conf" \
            "${effective_root}/etc/systemd/sleep.conf.d/sleep.conf"
    fi

    # zram-generator.conf -> /etc/systemd/zram-generator.conf.d/
    if [[ -f "${hardware_dir}/systemd/zram-generator.conf" ]]; then
        "$callback" "${hardware_dir}/systemd/zram-generator.conf" \
            "${effective_root}/etc/systemd/zram-generator.conf.d/override.conf"
    fi
}
