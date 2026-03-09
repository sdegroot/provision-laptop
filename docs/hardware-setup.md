# Hardware Setup — Tongfang GX4

## Target Hardware

- **Laptop:** Tongfang GX4 (OEM for Tuxedo laptops)
- **CPU:** AMD Ryzen (with AMD P-State driver)
- **GPU:** AMD RDNA integrated graphics
- **Ethernet:** Motorcomm YT6801 (requires out-of-tree DKMS driver)
- **WiFi:** Works out of the box on Fedora

## Prerequisites

- Disable Secure Boot in BIOS (simplifies DKMS module loading)
- WiFi available for initial provisioning (Ethernet driver installed later)

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
| `lm_sensors` | all | Hardware sensor monitoring |

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
