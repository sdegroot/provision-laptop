#!/usr/bin/env bash
# webcam/check.sh — Verify webcam enhancement setup.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

drift_found=0

# Only relevant on x86_64 (real hardware with GPU)
if [[ "$(uname -m)" != "x86_64" ]]; then
    log_warn "Skipping webcam check (not x86_64)"
    exit 0
fi

# Check v4l2loopback module
if lsmod | grep -q v4l2loopback 2>/dev/null; then
    log_ok "v4l2loopback module loaded"
elif modinfo v4l2loopback &>/dev/null; then
    log_warn "v4l2loopback module available but not loaded"
else
    log_error "v4l2loopback module not available (needs akmod-v4l2loopback + reboot)"
    drift_found=1
fi

# Check virtual camera device
if [[ -e /dev/video10 ]]; then
    log_ok "Virtual camera device: /dev/video10"
else
    log_error "Virtual camera device /dev/video10 not found"
    drift_found=1
fi

# Check GStreamer vaapipostproc plugin
if gst-inspect-1.0 vaapipostproc &>/dev/null 2>&1; then
    log_ok "GStreamer vaapipostproc plugin available"
else
    log_error "GStreamer vaapipostproc plugin not found (needs gstreamer1-vaapi)"
    drift_found=1
fi

# Check webcam-enhance script
if [[ -x "${PROVISION_DIR}/bin/webcam-enhance" ]]; then
    log_ok "webcam-enhance script"
else
    log_error "webcam-enhance script missing or not executable"
    drift_found=1
fi

# Check systemd user service
if [[ -z "${PROVISION_ROOT:-}" ]]; then
    if systemctl --user is-enabled --quiet webcam-enhance.service 2>/dev/null; then
        log_ok "Service enabled: webcam-enhance.service"
    else
        log_error "Service not enabled: webcam-enhance.service"
        drift_found=1
    fi
fi

exit $drift_found
