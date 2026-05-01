#!/usr/bin/env bash
# test_sync_bookmarks.sh — Tests for bin/sync-bookmarks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing: bin/sync-bookmarks..."

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Build a fixture Bookmarks file with noisy fields to be stripped.
make_fixture() {
    local out="$1"
    cat > "$out" <<'JSON'
{
  "checksum": "deadbeef",
  "sync_metadata": "irrelevant",
  "version": 1,
  "roots": {
    "bookmark_bar": {
      "children": [
        {
          "id": "12345",
          "guid": "stable-guid-1",
          "name": "Example",
          "type": "url",
          "url": "https://example.com",
          "date_added": "13422099641397737",
          "date_last_used": "13500000000000000",
          "meta_info": {
            "power_bookmark_meta": "keep-me",
            "last_visited_desktop": "13500000000000000",
            "stars.cluster_uuid": "drop-me"
          }
        }
      ],
      "id": "1",
      "guid": "bookmark_bar_guid",
      "name": "Bookmarks",
      "type": "folder"
    },
    "other": { "children": [], "id": "2", "guid": "other_guid", "type": "folder" }
  }
}
JSON
}

# Run the script with a custom HOME pointing at a tmp Brave layout. Returns the
# absolute path of the captured state file via stdout for the subsequent test.
setup_brave_tmp() {
    local profile="$1"
    local tmp_home="${TEST_TMPDIR}/home"
    local profile_dir="${tmp_home}/Library/Application Support/BraveSoftware/Brave-Browser/${profile}"
    mkdir -p "$profile_dir"
    make_fixture "${profile_dir}/Bookmarks"
}

# --- strip behavior ---

begin_test "pull strips noisy fields and keeps stable ones"
setup_test_tmpdir
setup_brave_tmp "Personal"

# Use a private profile-conf via a tmp PROVISION_DIR so the real repo isn't touched.
custom_dir="${TEST_TMPDIR}/repo"
mkdir -p "${custom_dir}/lib" "${custom_dir}/state" "${custom_dir}/bin"
cp "${REPO_ROOT}/lib/common.sh" "${custom_dir}/lib/"
cp "${REPO_ROOT}/bin/sync-bookmarks" "${custom_dir}/bin/"
echo "Personal Personal #FB8C00" > "${custom_dir}/state/brave-profiles.conf"

(
    export HOME="${TEST_TMPDIR}/home"
    "${custom_dir}/bin/sync-bookmarks" pull >/dev/null 2>&1
)

result_file="${custom_dir}/state/bookmarks/brave-Personal.json"
if [[ ! -f "$result_file" ]]; then
    fail_test "pull did not write expected file"
else
    content="$(cat "$result_file")"
    # Stripped fields
    if [[ "$content" == *"checksum"* ]]; then fail_test "checksum not stripped"
    elif [[ "$content" == *"sync_metadata"* ]]; then fail_test "sync_metadata not stripped"
    elif [[ "$content" == *"date_last_used"* ]]; then fail_test "date_last_used not stripped"
    elif [[ "$content" == *"last_visited_desktop"* ]]; then fail_test "last_visited_desktop not stripped"
    elif [[ "$content" == *"\"id\":"* ]]; then fail_test "id not stripped"
    # Kept fields
    elif [[ "$content" != *"stable-guid-1"* ]]; then fail_test "guid not preserved"
    elif [[ "$content" != *"https://example.com"* ]]; then fail_test "url not preserved"
    elif [[ "$content" != *"power_bookmark_meta"* ]]; then fail_test "kept meta_info field dropped"
    elif [[ "$content" != *"date_added"* ]]; then fail_test "date_added not preserved"
    else
        pass_test
    fi
fi
teardown_test_tmpdir

# --- pull-then-push round trip ---

begin_test "push restores bookmarks to a target profile"
setup_test_tmpdir
setup_brave_tmp "Personal"

custom_dir="${TEST_TMPDIR}/repo"
mkdir -p "${custom_dir}/lib" "${custom_dir}/state" "${custom_dir}/bin"
cp "${REPO_ROOT}/lib/common.sh" "${custom_dir}/lib/"
cp "${REPO_ROOT}/bin/sync-bookmarks" "${custom_dir}/bin/"
echo "Personal Personal #FB8C00" > "${custom_dir}/state/brave-profiles.conf"

# Pull from fixture into repo state.
(
    export HOME="${TEST_TMPDIR}/home"
    "${custom_dir}/bin/sync-bookmarks" pull >/dev/null 2>&1
)

# Wipe the live profile and push.
rm "${TEST_TMPDIR}/home/Library/Application Support/BraveSoftware/Brave-Browser/Personal/Bookmarks"
(
    export HOME="${TEST_TMPDIR}/home"
    export SYNC_BOOKMARKS_SKIP_BRAVE_GUARD=1
    "${custom_dir}/bin/sync-bookmarks" push >/dev/null 2>&1
)

restored="${TEST_TMPDIR}/home/Library/Application Support/BraveSoftware/Brave-Browser/Personal/Bookmarks"
if [[ -f "$restored" ]] && grep -q "stable-guid-1" "$restored"; then
    pass_test
else
    fail_test "push did not restore the live Bookmarks file"
fi
teardown_test_tmpdir

# --- skipping when no profile ---

begin_test "pull skips profiles without a live Bookmarks file"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/repo"
mkdir -p "${custom_dir}/lib" "${custom_dir}/state" "${custom_dir}/bin"
cp "${REPO_ROOT}/lib/common.sh" "${custom_dir}/lib/"
cp "${REPO_ROOT}/bin/sync-bookmarks" "${custom_dir}/bin/"
echo "Personal Personal #FB8C00" > "${custom_dir}/state/brave-profiles.conf"
mkdir -p "${TEST_TMPDIR}/home"

output="$(
    export HOME="${TEST_TMPDIR}/home"
    "${custom_dir}/bin/sync-bookmarks" pull 2>&1
)"

assert_contains "$output" "no live Bookmarks file"
teardown_test_tmpdir

print_test_summary "bin/sync-bookmarks"
