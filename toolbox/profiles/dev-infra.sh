#!/usr/bin/env bash
# dev-infra.sh — Setup for the dev-infra toolbox.
set -euo pipefail

echo "=== dev-infra profile setup ==="

# Additional infra tools that aren't in Fedora repos
# (installed via their official methods)

# AWS CLI
if ! command -v aws &>/dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
    cd /tmp && unzip -q awscliv2.zip
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
fi

echo "=== dev-infra setup complete ==="
