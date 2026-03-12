# S2idle Diagnostics — SKIKK Green 7

## System Information

| Item | Value |
|------|-------|
| **Laptop** | SKIKK Green 7 (Tongfang GX4, STX\KRK) |
| **CPU** | AMD Ryzen AI 9 HX 370 (family 1a, model 24) |
| **Kernel** | 6.17.1-300.fc43.x86_64 |
| **OS** | Fedora Linux 43.1.6 (Silverblue) |
| **BIOS** | N.1.20PCS09 (2025-09-29) |
| **EC Firmware** | 1.22 |
| **WiFi** | MediaTek mt7921e (PCI `0000:63:00.0`) |
| **Ethernet** | Motorcomm YT6801 (PCI `0000:64:00.0`) |

## Result Summary

S2idle works. The system enters and exits S0ix successfully.

| Metric | Value |
|--------|-------|
| Hardware sleep residency | 66.67% |
| Timekeeping suspended | 9.300 seconds (12s test) |
| Hardware sleep cycles | 1 |
| Battery delta | 0.00% |
| SMU idlemask | `0xffff9afd` |

All PEP transitions succeed except `screen on` on resume (see [Issue 1](#1-acpi-bios-bug-missing-_sbacdc-symbol) below).

### Successful PEP Transitions

```
ACPI: \_SB_.PEP_: Successfully transitioned to state screen off
ACPI: \_SB_.PEP_: Successfully transitioned to state lps0 ms entry
ACPI: \_SB_.PEP_: Successfully transitioned to state lps0 entry
ACPI: \_SB_.PEP_: Successfully transitioned to state lps0 exit
ACPI: \_SB_.PEP_: Successfully transitioned to state lps0 ms exit
```

Uses the Microsoft uPEP GUID in LPS0 `_DSM`.

### Resume Timing

| Phase | Duration |
|-------|----------|
| PM noirq resume | 154.356 ms |
| PM early resume | 2.269 ms |
| PM resume of devices complete | 262.460 ms |
| PM resume devices total | 0.264 seconds |

## Known Issues

### 1. ACPI BIOS Bug — Missing `\_SB.ACDC` Symbol

**Severity:** Low — system resumes fine, but the `screen on` PEP transition is aborted.

On resume, the PEP `_DSM` method references `\_SB.ACDC.RTAC`, which does not exist in this BIOS:

```
ACPI BIOS Error (bug): Could not resolve symbol [\_SB.ACDC.RTAC], AE_NOT_FOUND (20250404/psargs-332)
ACPI Error: Aborting method \_SB.PEP._DSM due to previous error (AE_NOT_FOUND) (20250404/psparse-529)
ACPI: \_SB_.PEP_: Failed to transitioned to state screen on
```

This is a SKIKK/Tongfang firmware bug — the ACPI tables reference a symbol (`RTAC` in the `ACDC` device scope) that was never defined. The `screen on` transition is the final step in the resume sequence and its failure has no functional impact: the screen turns on, devices resume, and the system works normally.

**Fix:** Requires a BIOS update from SKIKK to define the missing ACPI symbol.

### 2. LPI Constraint Warnings (GPP5/GPP6 in D0)

**Severity:** Informational — does not block S0ix entry.

The WLAN and Ethernet PCI bridges stay in D0 instead of reaching D1:

```
ACPI: \_SB_.PCI0.GPP5: LPI: Constraint not met; min power state:D1, current: D0
ACPI: \_SB_.PCI0.GPP6: LPI: Constraint not met; min power state:D1, current: D0
```

- **GPP5** → `mt7921e` WiFi (`0000:63:00.0`)
- **GPP6** → `yt6801` Ethernet (`0000:64:00.0`)

Despite these constraints not being met, the system still achieves S0ix — confirmed by the SMU idlemask (`0xffff9afd`) and 66.67% hardware sleep residency.

#### Workaround for Ethernet D0

If Ethernet is not needed during sleep, unbinding the `yt6801` driver allows GPP6 to enter D1:

```bash
# Unbind before sleep
echo "0000:64:00.0" | sudo tee /sys/bus/pci/drivers/yt6801/unbind

# Rebind after wake (or reboot)
echo "0000:64:00.0" | sudo tee /sys/bus/pci/drivers/yt6801/bind
```

This is optional — S0ix works regardless.

### 3. Tainted Kernel (12288)

**Severity:** Expected — no action needed.

Kernel taint value `12288` (`0x3000`) indicates:
- Bit 12: Unsigned module loaded
- Bit 13: Module from staging tree

This is caused by `tuxedo-drivers-kmod` from the `gladion136/tuxedo-drivers-kmod` COPR, which builds unsigned kernel modules via akmods. See [hardware-setup.md](hardware-setup.md) for why this COPR is used instead of DKMS.

### 4. "Device Not Power Manageable" Messages

**Severity:** Normal — these devices are managed by their own drivers, not ACPI power management.

```
ACPI: \_SB_.PCI0.GPP5.WLAN: LPI: Device not power manageable    # MediaTek WiFi
ACPI: \_SB_.PCI0.GPP6.GLAN: LPI: Device not power manageable    # Motorcomm Ethernet
ACPI: \_SB_.PCI0.GPPB.IPU_: LPI: Device not power manageable    # Image Processing Unit
ACPI: \_SB_.PCI0.GPPC.NHI0: LPI: Device not power manageable    # Thunderbolt
ACPI: \_SB_.I2CB.TPAD: LPI: Device not power manageable          # Touchpad
ACPI: \_SB_.PLTF.C000-C017: LPI: Device not power manageable    # CPU cores (24 entries)
```

These are informational messages from the LPI (Low Power Idle) subsystem. The devices handle their own power state transitions through their respective drivers rather than through ACPI `_PS0`/`_PS3` methods.

## How to Run

```bash
# Run s2idle diagnostics (requires sudo, performs a ~12s suspend cycle)
bin/s2idle-debug

# Run with custom suspend duration
bin/s2idle-debug test --duration 30
```

See [bin/s2idle-debug](../bin/s2idle-debug) for full usage. The script installs `amd-debug-tools` via pip in a mise-managed Python environment and runs `amd_s2idle`.

## Related Configuration

- **Kernel parameter:** `acpi.ec_no_wakeup=1` — prevents EC wakeups that block deepest S0ix state
- **Kernel parameter:** `i8042.reset=1` — forces PS/2 controller reset on resume (fixes keyboard)
- **Systemd:** `suspend-then-hibernate` — suspends for 60 minutes, then hibernates to save battery
- See [hardware-setup.md](hardware-setup.md) for full kernel parameter and systemd configuration
