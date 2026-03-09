#!/usr/bin/env bash
# download-iso.sh — Download Fedora Silverblue aarch64 ISO (latest stable).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="${SCRIPT_DIR}"

# Fedora 41 Silverblue aarch64
FEDORA_VERSION="${FEDORA_VERSION:-41}"
ISO_NAME="Fedora-Silverblue-ostree-aarch64-${FEDORA_VERSION}-1.4.iso"
ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Silverblue/aarch64/iso/${ISO_NAME}"
ISO_PATH="${ISO_DIR}/${ISO_NAME}"

if [[ -f "$ISO_PATH" ]]; then
    echo "ISO already exists: ${ISO_PATH}"
    echo "Delete it first if you want to re-download."
    exit 0
fi

echo "Downloading Fedora Silverblue ${FEDORA_VERSION} aarch64..."
echo "URL: ${ISO_URL}"
echo "Destination: ${ISO_PATH}"
echo ""

curl -L --progress-bar -o "${ISO_PATH}" "${ISO_URL}"

echo ""
echo "Download complete: ${ISO_PATH}"
echo "Size: $(du -h "${ISO_PATH}" | cut -f1)"
