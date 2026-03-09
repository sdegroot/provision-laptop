#!/usr/bin/env bash
# host-packages/plan.sh — Show planned host package changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "host-packages.txt")"

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping host-packages plan"
    exit 0
fi

changes_planned=0

layered="$(rpm-ostree status --json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
deployments = data.get("deployments", [])
if deployments:
    pkgs = deployments[0].get("requested-packages", [])
    for p in pkgs:
        print(p)
' 2>/dev/null || true)"

while IFS= read -r pkg; do
    if ! echo "$layered" | grep -q "^${pkg}$"; then
        log_plan "Would install host package: ${pkg}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No host package changes needed"
fi
