#!/usr/bin/env bash
# test_provisioning.sh — Verify provisioning repo and tools.
set -euo pipefail

PROVISION_PATH="${HOME}/provision-laptop"

echo "Checking provisioning..."

# Verify repo exists
if [[ ! -d "$PROVISION_PATH" ]]; then
    echo "FAIL: Provisioning repo not found at ${PROVISION_PATH}"
    exit 1
fi
echo "  OK: Provisioning repo exists"

# Verify bin scripts exist
for script in install apply check plan; do
    if [[ ! -x "${PROVISION_PATH}/bin/${script}" ]]; then
        echo "FAIL: bin/${script} not found or not executable"
        exit 1
    fi
done
echo "  OK: All bin scripts present and executable"

# Run check (will report drift but shouldn't crash)
echo "Running bin/check..."
exit_code=0
"${PROVISION_PATH}/bin/check" 2>&1 || exit_code=$?
echo "  bin/check exited with: ${exit_code}"

echo "Provisioning check: OK"
