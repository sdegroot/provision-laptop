#!/usr/bin/env bash
# webcam/apply.sh — Apply webcam enhancement setup.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_made=0

# Only relevant on x86_64 (real hardware with GPU)
if [[ "$(uname -m)" != "x86_64" ]]; then
    log_warn "Skipping webcam apply (not x86_64)"
    exit 0
fi

if [[ -z "${PROVISION_ROOT:-}" ]]; then
    # Load v4l2loopback if available but not loaded
    if ! lsmod | grep -q v4l2loopback 2>/dev/null; then
        if modinfo v4l2loopback &>/dev/null; then
            log_info "Loading v4l2loopback module"
            sudo modprobe v4l2loopback
            changes_made=1
        else
            log_warn "v4l2loopback module not available — install akmod-v4l2loopback and reboot"
        fi
    fi

    # Enable the systemd user service
    if ! systemctl --user is-enabled --quiet webcam-enhance.service 2>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || true
        log_info "Enabling webcam-enhance.service"
        systemctl --user enable webcam-enhance.service
        changes_made=1
    fi
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "Webcam enhancement already configured"
else
    log_ok "Webcam enhancement applied"
fi
