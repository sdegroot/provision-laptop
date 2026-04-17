#!/usr/bin/env bash
# Stop known S0i3 blockers before suspend, restart them after resume.
#
# Deployed to /usr/lib/systemd/system-sleep/ by the hardware module.
# systemd calls this with two arguments: "pre"/"post" and "suspend"/"hibernate"/etc.

case "$1" in
    pre)
        # Unload v4l2loopback — keeps media engine (IPU/UMSCH/VPE) from idling
        if lsmod | grep -q v4l2loopback; then
            modprobe -r v4l2loopback 2>/dev/null || true
        fi
        ;;
    post)
        # Reload v4l2loopback if its config exists (it was loaded at boot)
        if [ -f /etc/modprobe.d/v4l2loopback.conf ] && ! lsmod | grep -q v4l2loopback; then
            modprobe v4l2loopback 2>/dev/null || true
        fi
        ;;
esac
