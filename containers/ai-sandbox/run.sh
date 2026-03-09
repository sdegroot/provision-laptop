#!/usr/bin/env bash
# run.sh — Run the AI sandbox container.
#
# Mounts only the specified project directory, not $HOME.
set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

CONTAINER_NAME="ai-sandbox"
IMAGE_NAME="localhost/ai-sandbox:latest"

# Build if image doesn't exist
if ! podman image exists "$IMAGE_NAME"; then
    echo "Building AI sandbox image..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    podman build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

echo "Starting AI sandbox..."
echo "  Project: ${PROJECT_DIR} -> /workspace"
echo ""

exec podman run -it --rm \
    --name "$CONTAINER_NAME" \
    --security-opt=no-new-privileges \
    --cap-drop=ALL \
    -v "${PROJECT_DIR}:/workspace:Z" \
    "$IMAGE_NAME"
