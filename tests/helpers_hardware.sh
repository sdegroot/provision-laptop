#!/usr/bin/env bash
# helpers_hardware.sh — Test setup helpers for the hardware module.
#
# Provides reusable functions to set up and populate hardware test environments,
# reducing boilerplate across hardware test cases.

# setup_hardware_test_env <custom_dir>
#   Creates a minimal hardware module tree at <custom_dir> with all module
#   scripts, shared libraries, state files, and hardware config files copied
#   from the repository.
setup_hardware_test_env() {
    local custom_dir="$1"

    mkdir -p "${custom_dir}/lib/modules/hardware"
    mkdir -p "${custom_dir}/state"
    mkdir -p "${custom_dir}/hardware/"{modprobe,sysctl,dracut,systemd,udev}

    cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
    cp "${SCRIPT_DIR}/../lib/modules/hardware/"*.sh "${custom_dir}/lib/modules/hardware/"
    cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"
    cp "${SCRIPT_DIR}/../hardware/modprobe/"*.conf "${custom_dir}/hardware/modprobe/"
    cp "${SCRIPT_DIR}/../hardware/sysctl/"*.conf "${custom_dir}/hardware/sysctl/"
    cp "${SCRIPT_DIR}/../hardware/dracut/"*.conf "${custom_dir}/hardware/dracut/"
    cp "${SCRIPT_DIR}/../hardware/systemd/"* "${custom_dir}/hardware/systemd/"
    # udev rules (may not exist yet — use glob guard)
    for f in "${SCRIPT_DIR}/../hardware/udev/"*.rules; do
        [[ -f "$f" ]] && cp "$f" "${custom_dir}/hardware/udev/"
    done
}

# deploy_hardware_configs_to_fake_root <custom_dir> <fake_root>
#   Copies all hardware config files from <custom_dir> into the appropriate
#   target directories under <fake_root>, simulating a fully-deployed state.
deploy_hardware_configs_to_fake_root() {
    local custom_dir="$1"
    local fake_root="$2"

    mkdir -p "${fake_root}/etc/modprobe.d" "${fake_root}/etc/sysctl.d" \
        "${fake_root}/etc/dracut.conf.d" "${fake_root}/etc/udev/rules.d" \
        "${fake_root}/etc/systemd/system" \
        "${fake_root}/etc/systemd/sleep.conf.d" \
        "${fake_root}/etc/systemd/zram-generator.conf.d"

    cp "${custom_dir}/hardware/modprobe/"*.conf "${fake_root}/etc/modprobe.d/"
    cp "${custom_dir}/hardware/sysctl/"*.conf "${fake_root}/etc/sysctl.d/"
    cp "${custom_dir}/hardware/dracut/"*.conf "${fake_root}/etc/dracut.conf.d/"
    cp "${custom_dir}/hardware/systemd/"*.service "${fake_root}/etc/systemd/system/"
    cp "${custom_dir}/hardware/systemd/"*.timer "${fake_root}/etc/systemd/system/"
    cp "${custom_dir}/hardware/systemd/sleep.conf" "${fake_root}/etc/systemd/sleep.conf.d/"
    # udev rules
    for f in "${custom_dir}/hardware/udev/"*.rules; do
        [[ -f "$f" ]] && cp "$f" "${fake_root}/etc/udev/rules.d/"
    done
    # zram-generator override
    if [[ -f "${custom_dir}/hardware/systemd/zram-generator.conf" ]]; then
        cp "${custom_dir}/hardware/systemd/zram-generator.conf" \
            "${fake_root}/etc/systemd/zram-generator.conf.d/override.conf"
    fi
}
