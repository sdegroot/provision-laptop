#!/usr/bin/env bash
# webcam/plan.sh — Show planned webcam enhancement changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_planned=0

# Only relevant on x86_64 (real hardware with GPU)
if [[ "$(uname -m)" != "x86_64" ]]; then
    log_warn "Skipping webcam plan (not x86_64)"
    exit 0
fi

if [[ -z "${PROVISION_ROOT:-}" ]]; then
    # v4l2loopback
    if ! lsmod | grep -q v4l2loopback 2>/dev/null; then
        if modinfo v4l2loopback &>/dev/null; then
            log_plan "Would load v4l2loopback module"
            changes_planned=1
        else
            log_plan "v4l2loopback not available — needs akmod-v4l2loopback + reboot"
            changes_planned=1
        fi
    fi

    # systemd user service
    if ! systemctl --user is-enabled --quiet webcam-enhance.service 2>/dev/null; then
        log_plan "Would enable webcam-enhance.service"
        changes_planned=1
    fi
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No webcam changes needed"
fi
