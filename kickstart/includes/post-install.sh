#!/usr/bin/env bash
# post-install.sh — Kickstart %post script for first-boot setup.
#
# This script is executed during kickstart installation.
# It prepares the system for the first-boot service that will
# clone the provisioning repo and run bin/install.

set -euo pipefail

REPO_URL="${PROVISION_REPO_URL:-https://github.com/sdegroot/provision-laptop.git}"
PROVISION_PATH="/home/admin/provision-laptop"
SERVICE_NAME="provision-first-boot"

echo "=== Post-install: Setting up first-boot provisioning ==="

# Install the first-boot systemd service
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<UNIT
[Unit]
Description=Provision Laptop — First Boot Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/${SERVICE_NAME}.done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/${SERVICE_NAME}.sh
ExecStartPost=/usr/bin/touch /var/lib/${SERVICE_NAME}.done
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console
User=root

[Install]
WantedBy=multi-user.target
UNIT

# Install the first-boot script
cat > "/usr/local/bin/${SERVICE_NAME}.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

REPO_URL="__REPO_URL__"
PROVISION_PATH="__PROVISION_PATH__"
ADMIN_USER="admin"

echo "=== First Boot: Provisioning laptop ==="

# Wait for network
for i in $(seq 1 30); do
    if ping -c 1 github.com &>/dev/null; then
        break
    fi
    echo "Waiting for network... ($i/30)"
    sleep 2
done

# Clone or update the provisioning repo
if [[ -d "${PROVISION_PATH}" ]]; then
    echo "Updating existing provisioning repo..."
    cd "$PROVISION_PATH"
    git pull --ff-only || true
else
    echo "Cloning provisioning repo..."
    git clone "$REPO_URL" "$PROVISION_PATH"
    chown -R "${ADMIN_USER}:${ADMIN_USER}" "$PROVISION_PATH"
fi

# Run install as the admin user
echo "Running provisioning..."
cd "$PROVISION_PATH"
sudo -u "$ADMIN_USER" bin/install

echo "=== First Boot: Provisioning complete ==="
SCRIPT

# Replace placeholders
sed -i "s|__REPO_URL__|${REPO_URL}|g" "/usr/local/bin/${SERVICE_NAME}.sh"
sed -i "s|__PROVISION_PATH__|${PROVISION_PATH}|g" "/usr/local/bin/${SERVICE_NAME}.sh"
chmod +x "/usr/local/bin/${SERVICE_NAME}.sh"

# Enable the service
systemctl enable "${SERVICE_NAME}.service"

echo "=== Post-install: First-boot service installed ==="
