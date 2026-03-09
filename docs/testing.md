# Testing

## Test Levels

### Unit Tests (Fast)

Run on any OS (macOS or Linux), no Silverblue required:

```bash
tests/run.sh
```

These test parsing logic, module mechanics, and state file handling.
They use `PROVISION_ROOT` to isolate from the real filesystem.

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
# 1. Destroy and recreate VM
make vm-destroy
make vm-create
make vm-start

# 2. Install OS (manual or kickstart)
# 3. SSH in and run provisioning
make vm-ssh
# Inside VM:
git clone <repo> ~/provision-laptop
~/provision-laptop/bin/install

# 4. Run smoke tests
tests/vm/run-smoke-tests.sh
```

## Writing Tests

### Unit Tests

- Place test files in `tests/test_*.sh`
- Source `tests/helpers.sh` for assertions
- Use `setup_test_tmpdir` / `teardown_test_tmpdir` for isolation
- Export `NO_COLOR=1` and `PROVISION_ALLOW_NONROOT=1`
- Keep tests fast — no network, no system modifications

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
| host-packages | tests/test_module_host_packages.sh | — |
| flatpaks | tests/test_module_flatpaks.sh | tests/smoke/test_flatpaks.sh |
| dotfiles | tests/test_module_dotfiles.sh | — |
| toolboxes | tests/test_module_toolboxes.sh | — |
| mise | tests/test_module_mise.sh | — |
| system | — | tests/smoke/test_system_basics.sh |
| provisioning | — | tests/smoke/test_provisioning.sh |
