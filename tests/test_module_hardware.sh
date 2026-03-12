#!/usr/bin/env bash
# test_module_hardware.sh — Tests for the hardware module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"
source "${SCRIPT_DIR}/helpers_hardware.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: hardware..."

# --- State file parsing ---

begin_test "kernel-params.txt is valid and parseable"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "kernel-params.txt")"
output="$(parse_state_file "$STATE_FILE")"

assert_contains "$output" "amd_pstate=active"
teardown_test_tmpdir

begin_test "kernel-params.txt has no empty entries after parsing"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "kernel-params.txt")"
has_empty=false
while IFS= read -r line; do
    if [[ -z "${line// /}" ]]; then
        has_empty=true
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ "$has_empty" == "false" ]]; then
    pass_test
else
    fail_test "State file contains empty entries after parsing"
fi
teardown_test_tmpdir

begin_test "kernel-params.txt contains expected params"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "kernel-params.txt")"
output="$(parse_state_file "$STATE_FILE")"

assert_contains "$output" "nowatchdog"
teardown_test_tmpdir

# --- Hardware config files exist in repo ---

begin_test "modprobe amdgpu.conf exists in repo"
setup_test_tmpdir
assert_file_exists "${SCRIPT_DIR}/../hardware/modprobe/amdgpu.conf"
teardown_test_tmpdir

begin_test "modprobe audio_powersave.conf exists in repo"
setup_test_tmpdir
assert_file_exists "${SCRIPT_DIR}/../hardware/modprobe/audio_powersave.conf"
teardown_test_tmpdir

begin_test "sysctl 99-laptop.conf exists in repo"
setup_test_tmpdir
assert_file_exists "${SCRIPT_DIR}/../hardware/sysctl/99-laptop.conf"
teardown_test_tmpdir

begin_test "dracut fido2.conf exists in repo"
setup_test_tmpdir
assert_file_exists "${SCRIPT_DIR}/../hardware/dracut/fido2.conf"
teardown_test_tmpdir

begin_test "btrfs-scrub service exists in repo"
setup_test_tmpdir
assert_file_exists "${SCRIPT_DIR}/../hardware/systemd/btrfs-scrub@.service"
teardown_test_tmpdir

begin_test "btrfs-scrub timer exists in repo"
setup_test_tmpdir
assert_file_exists "${SCRIPT_DIR}/../hardware/systemd/btrfs-scrub@.timer"
teardown_test_tmpdir

begin_test "sleep.conf exists in repo"
setup_test_tmpdir
assert_file_exists "${SCRIPT_DIR}/../hardware/systemd/sleep.conf"
teardown_test_tmpdir

# --- Config file deployment (check detects drift) ---

begin_test "check detects missing config files"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
setup_hardware_test_env "$custom_dir"

exit_code=0
output="$(
    export PROVISION_ROOT="${TEST_TMPDIR}/fake-root"
    mkdir -p "${PROVISION_ROOT}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh"
) 2>&1" || exit_code=$?

# Should detect drift (config files not deployed yet)
assert_equals "1" "$exit_code"
teardown_test_tmpdir

# --- Config file deployment (check passes after deploy) ---

begin_test "check passes when config files are deployed"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
fake_root="${TEST_TMPDIR}/fake-root"
setup_hardware_test_env "$custom_dir"
deploy_hardware_configs_to_fake_root "$custom_dir" "$fake_root"

# Create swapfile and fstab entry
mkdir -p "${fake_root}/var/swap"
truncate -s $((96 * 1024 * 1024 * 1024)) "${fake_root}/var/swap/swapfile"
cat > "${fake_root}/etc/fstab" <<'FSTAB'
/var/swap/swapfile none swap defaults,nofail 0 0
FSTAB

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh"
) 2>&1" || exit_code=$?

# Should pass (all files deployed, swapfile correct size, fstab correct, not Silverblue so kargs skipped)
assert_equals "0" "$exit_code"
teardown_test_tmpdir

# --- Plan shows what would be done ---

begin_test "plan reports config files to deploy"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
setup_hardware_test_env "$custom_dir"

# Don't deploy any config files — plan should report them
output="$(
    export PROVISION_ROOT="${TEST_TMPDIR}/fake-root"
    mkdir -p "${PROVISION_ROOT}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/plan.sh"
) 2>&1"
assert_contains "$output" "Would deploy"
teardown_test_tmpdir

begin_test "plan reports no changes when everything is deployed"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
fake_root="${TEST_TMPDIR}/fake-root"
setup_hardware_test_env "$custom_dir"
deploy_hardware_configs_to_fake_root "$custom_dir" "$fake_root"

output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/plan.sh"
) 2>&1"
assert_contains "$output" "No hardware changes needed"
teardown_test_tmpdir

# --- Check detects config drift ---

begin_test "check detects config file content drift"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
fake_root="${TEST_TMPDIR}/fake-root"
setup_hardware_test_env "$custom_dir"

mkdir -p "${fake_root}/etc/modprobe.d"

# Deploy with different content (simulating drift)
echo "# modified content" > "${fake_root}/etc/modprobe.d/amdgpu.conf"

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh"
) 2>&1" || exit_code=$?

assert_equals "1" "$exit_code"
teardown_test_tmpdir

# --- Check detects missing fstab swap entry ---

begin_test "check detects missing fstab swapfile entry"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
fake_root="${TEST_TMPDIR}/fake-root"
setup_hardware_test_env "$custom_dir"

mkdir -p "${fake_root}/etc" "${fake_root}/var/swap"

# Create swapfile but no fstab entry
truncate -s $((96 * 1024 * 1024 * 1024)) "${fake_root}/var/swap/swapfile"
echo '# empty fstab' > "${fake_root}/etc/fstab"

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh" 2>&1
)" || exit_code=$?

assert_equals "1" "$exit_code"
assert_contains "$output" "Missing fstab entry for /var/swap/swapfile"
teardown_test_tmpdir

begin_test "check passes with correct fstab swapfile entry"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
fake_root="${TEST_TMPDIR}/fake-root"
setup_hardware_test_env "$custom_dir"
deploy_hardware_configs_to_fake_root "$custom_dir" "$fake_root"

mkdir -p "${fake_root}/var/swap"

truncate -s $((96 * 1024 * 1024 * 1024)) "${fake_root}/var/swap/swapfile"
cat > "${fake_root}/etc/fstab" <<'FSTAB'
/var/swap/swapfile none swap defaults,nofail 0 0
FSTAB

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh" 2>&1
)" || exit_code=$?

assert_contains "$output" "Fstab: swapfile entry"
teardown_test_tmpdir

# --- Swapfile size drift detection ---

begin_test "check detects swapfile size mismatch"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
fake_root="${TEST_TMPDIR}/fake-root"
setup_hardware_test_env "$custom_dir"
deploy_hardware_configs_to_fake_root "$custom_dir" "$fake_root"

mkdir -p "${fake_root}/var/swap"

# Create an undersized swapfile (8GB instead of 96GB)
truncate -s $((8 * 1024 * 1024 * 1024)) "${fake_root}/var/swap/swapfile"
echo '/var/swap/swapfile none swap defaults,nofail 0 0' > "${fake_root}/etc/fstab"

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh" 2>&1
)" || exit_code=$?

assert_equals "1" "$exit_code"
assert_contains "$output" "Swapfile size mismatch: expected 96GB, got 8GB"
teardown_test_tmpdir

begin_test "check passes when swapfile is correct size"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
fake_root="${TEST_TMPDIR}/fake-root"
setup_hardware_test_env "$custom_dir"
deploy_hardware_configs_to_fake_root "$custom_dir" "$fake_root"

mkdir -p "${fake_root}/var/swap"

truncate -s $((96 * 1024 * 1024 * 1024)) "${fake_root}/var/swap/swapfile"
echo '/var/swap/swapfile none swap defaults,nofail 0 0' > "${fake_root}/etc/fstab"

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh" 2>&1
)" || exit_code=$?

assert_equals "0" "$exit_code"
teardown_test_tmpdir

print_test_summary "module: hardware"
