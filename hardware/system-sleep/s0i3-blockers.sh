#!/usr/bin/env bash
# Stop known S0i3 blockers before suspend, restart them after resume.
#
# Deployed to /etc/systemd/system-sleep/ by the hardware module.
# systemd calls this with two arguments: "pre"/"post" and "suspend"/"hibernate"/etc.

case "$1" in
    pre)
        # Unload camera/media modules — keeps IPU and UMSCH from idling
        if lsmod | grep -q v4l2loopback; then
            modprobe -r v4l2loopback 2>/dev/null || true
        fi
        if lsmod | grep -q uvcvideo; then
            modprobe -r uvcvideo 2>/dev/null || true
        fi
        ;;
    post)
        # Reload camera modules
        if ! lsmod | grep -q uvcvideo; then
            modprobe uvcvideo 2>/dev/null || true
        fi
        if [ -f /etc/modprobe.d/v4l2loopback.conf ] && ! lsmod | grep -q v4l2loopback; then
            modprobe v4l2loopback 2>/dev/null || true
        fi
        ;;
esac
