# Testing

## Test Levels

### Unit Tests (Fast)

Run on any OS (macOS or Linux), no Silverblue required:

```bash
make test
# or: tests/run.sh
```

These test parsing logic, module mechanics, and state file handling.
They use `PROVISION_ROOT` to isolate from the real filesystem and
`PROVISION_ARCH` to test architecture filtering.

Target: < 30 seconds.

### Smoke Tests (VM)

Run against a Fedora Silverblue VM:

```bash
# Start the VM
make vm-start

# Run smoke tests
tests/vm/run-smoke-tests.sh
```

These verify the actual system state inside a running Silverblue instance.

### End-to-End Test

Full lifecycle validation:

```bash
# 1. Automated kickstart install
make vm-kickstart
# Wait for install, close QEMU window after reboot

# 2. Start VM and SSH in
VM_NOGRAPHIC=1 make vm-start
make vm-ssh
# Password: changeme

# 3. Inside VM: copy repo and run provisioning
# (from host):
sshpass -p changeme rsync -az --exclude='tests/vm/*.iso*' \
  --exclude='.git/' -e "ssh -p 2222" \
  ./  sdegroot@localhost:~/provision-laptop/

# 4. Inside VM: apply and check
sudo bash bin/apply
bin/check
```

## Writing Tests

### Unit Tests

- Place test files in `tests/test_*.sh`
- Source `tests/helpers.sh` for assertions
- Use `setup_test_tmpdir` / `teardown_test_tmpdir` for isolation
- Export `NO_COLOR=1` and `PROVISION_ALLOW_NONROOT=1`
- Keep tests fast — no network, no system modifications
- Use `PROVISION_ARCH=x86_64` to test arch-specific state file entries

Available assertions:

| Function | Purpose |
|----------|---------|
| `assert_equals expected actual` | Exact string match |
| `assert_contains haystack needle` | Substring match |
| `assert_not_contains haystack needle` | Substring absence |
| `assert_exit_code expected actual` | Exit code match |
| `assert_dir_exists path` | Directory exists |
| `assert_file_exists path` | File exists |
| `assert_symlink path` | Path is a symlink |

### Smoke Tests

- Place test files in `tests/smoke/test_*.sh`
- Tests run inside the VM via SSH
- Each test should be self-contained (no shared state)
- Use standard exit codes: 0 = pass, non-zero = fail

## Test Coverage

| Module | Unit Tests | Smoke Tests |
|--------|-----------|-------------|
| common.sh | tests/test_common.sh | — |
| engine.sh | tests/test_engine.sh | — |
| directories | tests/test_module_directories.sh | tests/smoke/test_directories.sh |
| repos | tests/test_module_repos.sh | — |
| host-packages | tests/test_module_host_packages.sh | — |
| flatpaks | tests/test_module_flatpaks.sh | tests/smoke/test_flatpaks.sh |
| dotfiles | tests/test_module_dotfiles.sh | — |
| hardware | tests/test_module_hardware.sh | — |
| toolboxes | tests/test_module_toolboxes.sh | — |
| mise | tests/test_module_mise.sh | — |
| system | — | tests/smoke/test_system_basics.sh |
| provisioning | — | tests/smoke/test_provisioning.sh |

## Architecture Testing

State files support `[arch]` tags. To verify parsing works for a specific architecture:

```bash
# Test as x86_64 (full config including tuxedo-drivers, yt6801-dkms)
PROVISION_ARCH=x86_64 bin/plan

# Test as aarch64 (VM config, x86_64-only entries skipped)
PROVISION_ARCH=aarch64 bin/plan
```

Unit tests use `PROVISION_ARCH` to test both code paths regardless of the host architecture.
