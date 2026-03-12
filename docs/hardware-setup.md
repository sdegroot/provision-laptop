# Hardware Setup — SKIKK Green 7

## Target Hardware

- **Laptop:** SKIKK Green 7 (Tongfang GX4 variant, STX\KRK)
- **CPU:** AMD Ryzen AI 9 HX 370 (with AMD P-State driver)
- **GPU:** AMD RDNA integrated graphics
- **Ethernet:** Motorcomm YT6801 (mainline in Fedora 43 kernel)
- **WiFi:** MediaTek mt7921e — works out of the box on Fedora

## Prerequisites

- WiFi available for initial provisioning (Ethernet driver installed later)
- BIOS settings configured (see BIOS Setup section below)

## BIOS Setup

Before installing Fedora Silverblue, configure BIOS settings for optimal compatibility and performance.

### How to Enter BIOS

1. Power off the laptop completely
2. Power on and immediately press **Delete** or **F2** (varies by model)
   - If BIOS doesn't open, try **F12** or **Esc** during startup
3. You should see the BIOS/UEFI menu

### Required Settings

| Setting | Value | Reason |
|---------|-------|--------|
| **Secure Boot** | **Disabled** | Required for DKMS modules (Ethernet driver, others) |
| **SATA Mode** | **AHCI** | Standard mode, usually default |
| **Virtualization (AMD-V)** | **Enabled** | Required for VMs, containers, KVM |

### Recommended Settings

| Setting | Value | Reason |
|---------|-------|--------|
| **XMP / DOCP** | Enabled (if RAM upgraded) | Better memory performance |
| **AMD PST / CPU Power Management** | Keep default | AMD P-State driver handles this |
| **Wake on LAN** | Disabled | Save battery if not needed |
| **Fingerprint Reader** | Enabled | For biometric authentication |
| **Integrated Camera** | Disable if unused | Save power, improve privacy |
| **Bluetooth** | Enable | WiFi card has integrated Bluetooth |

### Step-by-Step: Disable Secure Boot

1. Enter BIOS (press Delete/F2 at startup)
2. Navigate to **Security** tab
3. Find **Secure Boot** setting
4. Change to **Disabled**
5. If prompted, confirm and allow BIOS to reset defaults
6. Save and Exit (usually **F10**)

### Step-by-Step: Enable Virtualization

1. Enter BIOS
2. Navigate to **Processor** or **CPU** tab
3. Find **Virtualization Technology** or **SVM Mode**
4. Change to **Enabled**
5. Save and Exit (**F10**)

### Step-by-Step: Set SATA to AHCI

1. Enter BIOS
2. Navigate to **Storage** or **Integrated Peripherals**
3. Find **SATA Mode** or **Storage Configuration**
4. Change from RAID to **AHCI** (if not already set)
5. Save and Exit (**F10**)

### Verification After Boot

After installing Fedora Silverblue, verify BIOS settings took effect:

```bash
# Check Secure Boot is disabled
mokutil --sb-state

# Check virtualization is enabled
lscpu | grep -i virtual

# Check SATA mode
lsblk -d -o name,model
```

### Common BIOS Menu Layouts

**Different BIOS vendors use different tab names:**

| Item | AMI/Award BIOS | Phoenix BIOS | UEFI | Where to Look |
|------|---|---|---|---|
| Secure Boot | Security → Secure Boot | Security → Secure Boot | Security → Secure Boot | Usually under Security tab |
| Virtualization | Processor → Virtualization Tech | CPU → CPU Virtualization | Processor → SVM Mode | Under CPU/Processor settings |
| SATA Mode | Storage → SATA | Storage → SATA Mode | Integrated Peripherals → SATA | Storage/Peripherals section |

## What Gets Configured

### Kernel Parameters (`state/kernel-params.txt`)

Applied via `rpm-ostree kargs` — active after reboot.

| Parameter | Purpose |
|-----------|---------|
| `amd_pstate=active` | AMD P-State driver for better power management |
| `nowatchdog` | Disable watchdog timers (save power) |
| `nmi_watchdog=0` | Disable NMI watchdog (reduce wake-ups) |
| `workqueue.power_efficient=1` | Power-efficient work queues |
| `pcie_aspm=default` | PCIe Active State Power Management |

### Third-Party Repos (`state/repos.conf`)

| Repo | Type | Purpose |
|------|------|---------|
| Tuxedo | repofile | Fan control, keyboard backlight, EC interface drivers |
| RPM Fusion Free | release RPM | VA-API freeworld codecs |
| RPM Fusion Non-Free | release RPM | Additional codec support |
| nuzar/yt6801-dkms | COPR | Motorcomm YT6801 Ethernet driver |

The Tuxedo repo and yt6801-dkms COPR are tagged `[x86_64]` — they are skipped on aarch64 (VM development).

### Hardware Packages (`state/host-packages.txt`)

| Package | Arch | Purpose |
|---------|------|---------|
| `tuxedo-drivers` | x86_64 | Tuxedo EC interface, keyboard backlight |
| `tuxedo-control-center` | x86_64 | Fan curves, power profiles (GUI) |
| `yt6801-dkms` | x86_64 | Motorcomm YT6801 Ethernet (DKMS) |
| `libfido2` | all | FIDO2 library for YubiKey |
| `yubikey-manager` | all | YubiKey configuration tool (`ykman`) |
| `pam-u2f` | all | PAM module for U2F/FIDO2 auth |
| `fprintd` | all | Fingerprint daemon |
| `libfprint` | all | Fingerprint library |
| `lm_sensors` | all | Hardware sensor monitoring |
| `acpica-tools` | x86_64 | ACPI tools (`iasl`) for amd-debug-tools |
| `edid-decode` | x86_64 | Display EDID parser for AMD debug diagnostics |
| `libdisplay-info-tools` | x86_64 | Display info utilities for AMD debug diagnostics |

### Modprobe Configuration

**`hardware/modprobe/amdgpu.conf`** → `/etc/modprobe.d/`
- Enables FreeSync (Adaptive Sync) for the AMD GPU
- `options amdgpu dc=1` and `freesync_video=1`

**`hardware/modprobe/audio_powersave.conf`** → `/etc/modprobe.d/`
- Disables audio codec power saving to prevent pops/clicks on resume
- `options snd_hda_intel power_save=0`

### Sysctl Tuning

**`hardware/sysctl/99-laptop.conf`** → `/etc/sysctl.d/`

| Setting | Value | Purpose |
|---------|-------|---------|
| `fs.inotify.max_user_watches` | 524288 | IDEs and file watchers |
| `fs.inotify.max_user_instances` | 1024 | Multiple IDE instances |
| `net.core.default_qdisc` | fq | Fair queuing for TCP BBR |
| `net.ipv4.tcp_congestion_control` | bbr | Better throughput + lower latency |
| `vm.swappiness` | 10 | Prefer keeping apps in RAM |

### Dracut (Initramfs)

**`hardware/dracut/fido2.conf`** → `/etc/dracut.conf.d/`
- Includes FIDO2 support in initramfs for YubiKey LUKS unlock at boot
- See [YubiKey Setup](yubikey-setup.md) for enrollment instructions

### Systemd Configuration

**`hardware/systemd/btrfs-scrub@.service`** + **`btrfs-scrub@.timer`** → `/etc/systemd/system/`
- Monthly Btrfs integrity scrub
- Runs at idle I/O priority to avoid impacting performance
- Timer: `OnCalendar=monthly` with 1-week randomized delay

**`hardware/systemd/sleep.conf`** → `/etc/systemd/sleep.conf.d/`
- Suspend-then-hibernate: suspends for 60 minutes, then hibernates
- Saves battery during longer sleep periods

### Hibernate Setup

The hardware module creates:
1. Btrfs swap subvolume at `/swap` (with `chattr +C` for no copy-on-write)
2. 8GB swapfile at `/swap/swapfile`
3. Kernel resume parameters (`resume=UUID=... resume_offset=...`)
4. fstab entry for the swapfile

### Sleep (S2idle)

The system uses s2idle (S0ix / Modern Standby) for suspend, configured as `suspend-then-hibernate` via systemd — suspends for 60 minutes, then hibernates to save battery during longer sleep periods.

Key kernel parameters for sleep:
- `acpi.ec_no_wakeup=1` — prevents EC wakeups that block deepest S0ix state
- `i8042.reset=1` — forces PS/2 controller reset on resume (fixes keyboard not working after wake)

For detailed diagnostics output, known ACPI issues, and workarounds, see [S2idle Diagnostics](s2idle-diagnostics.md).

To run sleep diagnostics: `bin/s2idle-debug`

### VA-API Video Acceleration (x86_64 only)

The repos module swaps the default mesa VA-API drivers for freeworld versions:
```
rpm-ostree override remove mesa-va-drivers --install mesa-va-drivers-freeworld
rpm-ostree override remove mesa-vdpau-drivers --install mesa-vdpau-drivers-freeworld
```

This enables hardware video decoding (H.264, H.265) on the AMD GPU.

## Verification

```bash
# Check all hardware configuration
bin/check --module hardware

# Check repos are configured
bin/check --module repos

# Verify kernel params are active
cat /proc/cmdline

# Check sensors
sensors

# Check VA-API
vainfo

# Check Btrfs scrub timer
systemctl status btrfs-scrub@-.timer

# Check swap
swapon --show
```

## What Is NOT Automated

These require manual steps — see linked documentation.

| Item | Reason | Documentation |
|------|--------|---------------|
| YubiKey LUKS enrollment | Requires physical key tap | [YubiKey Setup](yubikey-setup.md) |
| Fingerprint enrollment | Requires fingerprint scans | [Fingerprint Setup](fingerprint-setup.md) |
| Firmware updates | User decides when to apply | `fwupdmgr get-updates` |
| Tuxedo Control Center fan profiles | Configured via GUI | See below |
| Battery charge thresholds | Depends on tuxedo-drivers EC | See below |

### Tuxedo Control Center

After provisioning, open Tuxedo Control Center to configure:
- Fan curve profiles (quiet, balanced, performance)
- Keyboard backlight color and brightness
- Power profiles

### Firmware Updates

```bash
# Check for available firmware updates
fwupdmgr get-updates

# Apply updates (review first)
fwupdmgr update
```

### Battery Charge Thresholds

If tuxedo-drivers exposes battery charge thresholds via sysfs:
```bash
# Check if available
ls /sys/class/power_supply/BAT0/charge_control_*

# Set threshold (example)
echo 80 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
```
