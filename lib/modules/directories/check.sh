#!/usr/bin/env bash
# directories/check.sh - Verify required directories exist.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "directories.txt")"
drift_found=0

while IFS= read -r line; do
    # Parse path:owner:mode
    IFS=':' read -r dir_path dir_owner dir_mode <<< "$line"

    # Expand ~ to HOME
    dir_path="${dir_path/#\~/$HOME}"
    # Expand ${USER} in owner
    dir_owner="${dir_owner:-$USER}"
    dir_owner="${dir_owner/\$\{USER\}/$USER}"
    dir_mode="${dir_mode:-0755}"

    # Apply PROVISION_ROOT for testing
    effective_path="${PROVISION_ROOT}${dir_path}"

    if [[ ! -d "$effective_path" ]]; then
        log_error "Missing directory: ${dir_path}"
        drift_found=1
        continue
    fi

    # Check permissions (portable: use stat)
    if [[ "$(uname)" == "Darwin" ]]; then
        current_mode=$(stat -f '%Lp' "$effective_path" 2>/dev/null || echo "unknown")
    else
        current_mode=$(stat -c '%a' "$effective_path" 2>/dev/null || echo "unknown")
    fi

    # Normalize expected mode (strip leading 0)
    expected_mode="${dir_mode#0}"

    if [[ "$current_mode" != "$expected_mode" ]]; then
        log_error "Wrong mode on ${dir_path}: expected ${dir_mode}, got ${current_mode}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All directories match desired state"
fi

exit $drift_found
