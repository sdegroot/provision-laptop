#!/usr/bin/env bash
# dev-infra.sh — Setup for the dev-infra toolbox.
set -euo pipefail

echo "=== dev-infra profile setup ==="

# Add HashiCorp repo for terraform (not in Fedora repos)
if ! dnf repolist 2>/dev/null | grep -q hashicorp; then
    echo "Adding HashiCorp repo..."
    sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    sudo dnf install -y terraform
fi

# AWS CLI — detect arch for correct installer
if ! command -v aws &>/dev/null; then
    echo "Installing AWS CLI..."
    arch="$(uname -m)"
    if [[ "$arch" == "aarch64" ]]; then
        aws_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
    else
        aws_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    fi
    curl "$aws_url" -o "/tmp/awscliv2.zip"
    cd /tmp && unzip -q awscliv2.zip
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
fi

echo "=== dev-infra setup complete ==="
