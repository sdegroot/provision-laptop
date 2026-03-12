#!/usr/bin/env bash
# test_module_hardware.sh — Tests for the hardware module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

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
mkdir -p "${custom_dir}/lib/modules/hardware"
mkdir -p "${custom_dir}/state"
mkdir -p "${custom_dir}/hardware/modprobe"
mkdir -p "${custom_dir}/hardware/sysctl"
mkdir -p "${custom_dir}/hardware/dracut"
mkdir -p "${custom_dir}/hardware/systemd"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/hardware/check.sh" "${custom_dir}/lib/modules/hardware/"
cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"
cp "${SCRIPT_DIR}/../hardware/modprobe/"*.conf "${custom_dir}/hardware/modprobe/"
cp "${SCRIPT_DIR}/../hardware/sysctl/"*.conf "${custom_dir}/hardware/sysctl/"
cp "${SCRIPT_DIR}/../hardware/dracut/"*.conf "${custom_dir}/hardware/dracut/"
cp "${SCRIPT_DIR}/../hardware/systemd/"* "${custom_dir}/hardware/systemd/"

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
mkdir -p "${custom_dir}/lib/modules/hardware"
mkdir -p "${custom_dir}/state"
mkdir -p "${custom_dir}/hardware/modprobe"
mkdir -p "${custom_dir}/hardware/sysctl"
mkdir -p "${custom_dir}/hardware/dracut"
mkdir -p "${custom_dir}/hardware/systemd"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/hardware/check.sh" "${custom_dir}/lib/modules/hardware/"
cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"
cp "${SCRIPT_DIR}/../hardware/modprobe/"*.conf "${custom_dir}/hardware/modprobe/"
cp "${SCRIPT_DIR}/../hardware/sysctl/"*.conf "${custom_dir}/hardware/sysctl/"
cp "${SCRIPT_DIR}/../hardware/dracut/"*.conf "${custom_dir}/hardware/dracut/"
cp "${SCRIPT_DIR}/../hardware/systemd/"* "${custom_dir}/hardware/systemd/"

# Deploy config files to the fake root
fake_root="${TEST_TMPDIR}/fake-root"
mkdir -p "${fake_root}/etc/modprobe.d" "${fake_root}/etc/sysctl.d" \
    "${fake_root}/etc/dracut.conf.d" "${fake_root}/etc/systemd/system" \
    "${fake_root}/etc/systemd/sleep.conf.d" "${fake_root}/swap"

cp "${custom_dir}/hardware/modprobe/"*.conf "${fake_root}/etc/modprobe.d/"
cp "${custom_dir}/hardware/sysctl/"*.conf "${fake_root}/etc/sysctl.d/"
cp "${custom_dir}/hardware/dracut/"*.conf "${fake_root}/etc/dracut.conf.d/"
cp "${custom_dir}/hardware/systemd/"*.service "${fake_root}/etc/systemd/system/"
cp "${custom_dir}/hardware/systemd/"*.timer "${fake_root}/etc/systemd/system/"
cp "${custom_dir}/hardware/systemd/sleep.conf" "${fake_root}/etc/systemd/sleep.conf.d/"

# Create fstab with swap mount entries
cat > "${fake_root}/etc/fstab" <<'FSTAB'
UUID=test-uuid /swap btrfs subvol=swap,nodatacow,nofail 0 0
/swap/swapfile none swap defaults,nofail,pri=10,x-systemd.requires=swap.mount 0 0
FSTAB

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh"
) 2>&1" || exit_code=$?

# Should pass (all files deployed, swap dir exists, fstab correct, not Silverblue so kargs skipped)
assert_equals "0" "$exit_code"
teardown_test_tmpdir

# --- Plan shows what would be done ---

begin_test "plan reports config files to deploy"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/hardware"
mkdir -p "${custom_dir}/state"
mkdir -p "${custom_dir}/hardware/modprobe"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/hardware/plan.sh" "${custom_dir}/lib/modules/hardware/"
cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"
cp "${SCRIPT_DIR}/../hardware/modprobe/"*.conf "${custom_dir}/hardware/modprobe/"

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
mkdir -p "${custom_dir}/lib/modules/hardware"
mkdir -p "${custom_dir}/state"
mkdir -p "${custom_dir}/hardware/modprobe"
mkdir -p "${custom_dir}/hardware/sysctl"
mkdir -p "${custom_dir}/hardware/dracut"
mkdir -p "${custom_dir}/hardware/systemd"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/hardware/plan.sh" "${custom_dir}/lib/modules/hardware/"
cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"
cp "${SCRIPT_DIR}/../hardware/modprobe/"*.conf "${custom_dir}/hardware/modprobe/"
cp "${SCRIPT_DIR}/../hardware/sysctl/"*.conf "${custom_dir}/hardware/sysctl/"
cp "${SCRIPT_DIR}/../hardware/dracut/"*.conf "${custom_dir}/hardware/dracut/"
cp "${SCRIPT_DIR}/../hardware/systemd/"* "${custom_dir}/hardware/systemd/"

fake_root="${TEST_TMPDIR}/fake-root"
mkdir -p "${fake_root}/etc/modprobe.d" "${fake_root}/etc/sysctl.d" \
    "${fake_root}/etc/dracut.conf.d" "${fake_root}/etc/systemd/system" \
    "${fake_root}/etc/systemd/sleep.conf.d"

cp "${custom_dir}/hardware/modprobe/"*.conf "${fake_root}/etc/modprobe.d/"
cp "${custom_dir}/hardware/sysctl/"*.conf "${fake_root}/etc/sysctl.d/"
cp "${custom_dir}/hardware/dracut/"*.conf "${fake_root}/etc/dracut.conf.d/"
cp "${custom_dir}/hardware/systemd/"*.service "${fake_root}/etc/systemd/system/"
cp "${custom_dir}/hardware/systemd/"*.timer "${fake_root}/etc/systemd/system/"
cp "${custom_dir}/hardware/systemd/sleep.conf" "${fake_root}/etc/systemd/sleep.conf.d/"

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
mkdir -p "${custom_dir}/lib/modules/hardware"
mkdir -p "${custom_dir}/state"
mkdir -p "${custom_dir}/hardware/modprobe"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/hardware/check.sh" "${custom_dir}/lib/modules/hardware/"
cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"
cp "${SCRIPT_DIR}/../hardware/modprobe/"*.conf "${custom_dir}/hardware/modprobe/"

fake_root="${TEST_TMPDIR}/fake-root"
mkdir -p "${fake_root}/etc/modprobe.d" "${fake_root}/swap"

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

# --- Check detects missing fstab swap entries ---

begin_test "check detects missing fstab swap mount entry"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/hardware"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/hardware/check.sh" "${custom_dir}/lib/modules/hardware/"
cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"

fake_root="${TEST_TMPDIR}/fake-root"
mkdir -p "${fake_root}/etc" "${fake_root}/swap"

# fstab with old-style swap entry (no subvolume mount, no ordering)
echo '/swap/swapfile none swap defaults 0 0' > "${fake_root}/etc/fstab"

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh" 2>&1
)" || exit_code=$?

assert_equals "1" "$exit_code"
assert_contains "$output" "Missing fstab entry for /swap subvolume mount"
assert_contains "$output" "Missing or incorrect fstab entry for /swap/swapfile"
teardown_test_tmpdir

begin_test "check passes with correct fstab swap entries"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/hardware"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/hardware/check.sh" "${custom_dir}/lib/modules/hardware/"
cp "${SCRIPT_DIR}/../state/kernel-params.txt" "${custom_dir}/state/"

fake_root="${TEST_TMPDIR}/fake-root"
mkdir -p "${fake_root}/etc" "${fake_root}/swap"

cat > "${fake_root}/etc/fstab" <<'FSTAB'
UUID=test-uuid /swap btrfs subvol=swap,nodatacow,nofail 0 0
/swap/swapfile none swap defaults,nofail,pri=10,x-systemd.requires=swap.mount 0 0
FSTAB

exit_code=0
output="$(
    export PROVISION_ROOT="${fake_root}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/hardware/check.sh" 2>&1
)" || exit_code=$?

# Should detect fstab entries as OK (config file drift is expected since we didn't deploy those)
assert_contains "$output" "Fstab: /swap subvolume mount entry"
assert_contains "$output" "Fstab: swapfile entry with mount ordering"
teardown_test_tmpdir

print_test_summary "module: hardware"
