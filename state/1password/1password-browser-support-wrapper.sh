#!/bin/bash
if [ "${container-}" = flatpak ]; then
    exec flatpak-spawn --host /usr/lib/opt/1Password/1Password-BrowserSupport "$@"
else
    exec /usr/lib/opt/1Password/1Password-BrowserSupport "$@"
fi
