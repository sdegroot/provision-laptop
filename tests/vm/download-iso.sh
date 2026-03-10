#!/usr/bin/env bash
# download-iso.sh — Download Fedora Silverblue ISO (latest stable).
#
# Usage:
#   tests/vm/download-iso.sh              # defaults to host architecture
#   tests/vm/download-iso.sh --arch x86_64
#   tests/vm/download-iso.sh --arch aarch64
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="${SCRIPT_DIR}"

FEDORA_VERSION="${FEDORA_VERSION:-43}"
ARCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="${2:?--arch requires a value (x86_64 or aarch64)}"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--arch x86_64|aarch64]"
            echo ""
            echo "Downloads Fedora Silverblue ISO for the specified architecture."
            echo "Defaults to the host architecture ($(uname -m))."
            echo ""
            echo "Environment variables:"
            echo "  FEDORA_VERSION  Fedora release version (default: 43)"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Default to host architecture
if [[ -z "$ARCH" ]]; then
    ARCH="$(uname -m)"
fi

# Validate architecture
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    echo "ERROR: Unsupported architecture: ${ARCH} (must be x86_64 or aarch64)"
    exit 1
fi

FEDORA_BUILD="${FEDORA_BUILD:-1.6}"
ISO_NAME="Fedora-Silverblue-ostree-${ARCH}-${FEDORA_VERSION}-${FEDORA_BUILD}.iso"
ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Silverblue/${ARCH}/iso/${ISO_NAME}"
ISO_PATH="${ISO_DIR}/${ISO_NAME}"

if [[ -f "$ISO_PATH" ]]; then
    echo "ISO already exists: ${ISO_PATH}"
    echo "Delete it first if you want to re-download."
    exit 0
fi

echo "Downloading Fedora Silverblue ${FEDORA_VERSION} ${ARCH}..."
echo "URL: ${ISO_URL}"
echo "Destination: ${ISO_PATH}"
echo ""

curl -L --progress-bar -o "${ISO_PATH}" "${ISO_URL}"

echo ""
echo "Download complete: ${ISO_PATH}"
echo "Size: $(du -h "${ISO_PATH}" | cut -f1)"
