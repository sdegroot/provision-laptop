# Tongfang GX4 / TUXEDO InfinityBook Pro 14 Gen9 -- Hardware Optimizations for Fedora

Research date: 2026-03-09

---

## 1. Hardware Identification

The **Tongfang GX4** is an ODM (Original Design Manufacturer) chassis sold under multiple brands:

| Brand | Model Name |
|---|---|
| TUXEDO | InfinityBook Pro 14 Gen9 / Gen10 |
| Schenker | XMG EVO 15 (15" variant) |
| SKIKK | Green 6 AMD |
| Laptop with Linux | Tongfang GX4 |

**Key hardware (GX4 current generation):**

- CPU: AMD Ryzen AI 7 350 (8C/16T) or AMD Ryzen AI 9 HX370 (12C/24T)
- GPU: Integrated AMD Radeon 860M / 890M
- WiFi: Intel AX210 (802.11AX dual-band + Bluetooth 5.2)
- Ethernet: **Motorcomm YT6801** Gigabit (PCI ID `1f0a:6801`) -- **requires out-of-tree driver**
- Display: 14" QHD+ 2880x1800 @ 120Hz
- RAM: Up to 128 GB DDR5 SODIMM
- Storage: 2x M.2 2280 PCIe Gen4x4
- Battery: 80 Wh
- Weight: 1.45 kg

The older Gen9 AMD variant uses Ryzen 7 8845HS with Radeon 780M and Intel Wireless 8260.

---

## 2. What tuxedo-drivers Provides

**Repository:**
- Primary: https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
- Mirror (read-only): https://github.com/tuxedocomputers/tuxedo-drivers

**tuxedo-drivers** is a DKMS package containing ~28 kernel modules for TUXEDO/Tongfang/Clevo/Uniwill hardware. It is the successor to the now-deprecated `tuxedo-keyboard` package.

### Kernel modules included

| Module | Purpose |
|---|---|
| `tuxedo_keyboard` | Keyboard backlight control via SysFS |
| `tuxedo_io` | Hardware I/O bridge for TCC (fan speed, temps, power) |
| `uniwill_wmi` | WMI interface for Uniwill/Tongfang embedded controller |
| `clevo_wmi` | WMI interface for Clevo-based chassis |
| `clevo_acpi` | ACPI interface for Clevo-based chassis |
| `ite_8291` | ITE keyboard backlight controller |
| `ite_8291_lb` | ITE keyboard backlight (light bar variant) |
| `ite_8297` | ITE keyboard backlight controller (variant) |
| `ite_829x` | ITE keyboard backlight controller (family) |
| `tuxedo_nb05*` | Platform drivers for specific notebook models |
| `tuxedo_nb04*` | Platform drivers for specific notebook models |
| `tuxedo_nb02*` | Platform drivers for specific notebook models |

### What these enable

- **Fan control**: Read fan RPM, set fan speed curves via `tuxedo_io` + `uniwill_wmi`
- **Keyboard backlight**: Color, brightness, effects via `tuxedo_keyboard` + ITE modules
- **Power management**: CPU power limits, TDP control via embedded controller
- **Function keys**: Fn+F10/F11/F12 (without the driver, these keys require extra kernel params)
- **Sensor data**: CPU/GPU temperatures exposed to userspace

### Tongfang-specific notes

The Tongfang GX4 uses the **Uniwill platform**, so the relevant modules are:
- `uniwill_wmi` (embedded controller communication)
- `tuxedo_keyboard` (keyboard backlight)
- `tuxedo_io` (hardware I/O for TCC)

The older `tuxedo-cc-wmi` repository contains a `tongfang_wmi.h` header, confirming direct Tongfang WMI support is built into these drivers.

---

## 3. tuxedo-drivers on Fedora -- Installation

### Option A: Official TUXEDO repository (recommended, available since mid-2025)

```bash
# Update system first
sudo dnf update

# Add TUXEDO repository
sudo dnf config-manager addrepo --from-repofile="https://rpm.tuxedocomputers.com/fedora/tuxedo.repo"

# Import GPG key (adjust Fedora version number)
# The key is available at https://rpm.tuxedocomputers.com/fedora/43/
sudo rpm --import https://rpm.tuxedocomputers.com/fedora/43/0x54840598.pub.asc

# Install (tuxedo-drivers is pulled in as a dependency)
sudo dnf install tuxedo-control-center
```

The repo URL pattern is `https://rpm.tuxedocomputers.com/fedora/{version}/x86_64/base/`.

### Option B: COPR repositories (community-maintained)

```bash
# tuxedo-drivers only
sudo dnf copr enable kallepm/tuxedo-drivers
sudo dnf install tuxedo-drivers

# Alternative COPR for tuxedo-control-center
# https://copr.fedorainfracloud.org/coprs/sbirk/tuxedo-control-center/
sudo dnf copr enable sbirk/tuxedo-control-center
sudo dnf install tuxedo-control-center
```

COPR packages:
- `kallepm/tuxedo-drivers` -- https://discussion.fedoraproject.org/t/kallepm-tuxedo-drivers/98610
- `ainmosni/tuxedo-drivers` -- https://discussion.fedoraproject.org/t/ainmosni-tuxedo-drivers/109966
- `sbirk/tuxedo-control-center` -- https://copr.fedorainfracloud.org/coprs/sbirk/tuxedo-control-center/

### Option C: Build from source

```bash
sudo dnf install dkms kernel-devel make gcc
git clone https://github.com/tuxedocomputers/tuxedo-drivers.git
cd tuxedo-drivers
# Follow Makefile targets for DKMS installation
```

### Fedora Silverblue consideration

On Silverblue, DKMS modules are problematic because the base system is immutable. Options:
1. **rpm-ostree overlay**: `rpm-ostree install tuxedo-drivers` (from the TUXEDO repo)
2. **Build into a custom image**: Use a Containerfile-based approach to layer the DKMS build
3. **Universal Blue**: Check if a ublue image variant includes tuxedo-drivers

---

## 4. TUXEDO Control Center (TCC)

**Repository:** https://github.com/tuxedocomputers/tuxedo-control-center

- **License:** GPLv3 -- yes, it is open source
- **Technology:** Electron-based GUI application + systemd daemon (`tccd.service`)
- **Depends on:** `tuxedo_io` kernel module from tuxedo-drivers

### Features

- **Power profiles**: Mains/Battery with automatic switching
- **Fan control**: Custom fan curves, silent/performance modes
- **CPU management**: Frequency scaling, core count, TDP limits
- **Keyboard backlight**: Color, brightness, effects
- **Display**: Refresh rate reduction for battery savings
- **Webcam**: Quality settings
- **Dashboard**: Real-time monitoring of clock speed, fan RPM, power draw, temperature, GPU mode

### systemd service

```bash
# Enabled automatically on install
sudo systemctl enable --now tccd.service
```

The `tccd` daemon runs as root and communicates with the `tuxedo_io` kernel module to manage hardware.

---

## 5. ACPI Quirks and Kernel Parameters

### Required/recommended kernel parameters for Tongfang GX4

| Parameter | Purpose | When needed |
|---|---|---|
| `i8042.reset i8042.nomux i8042.nopnp i8042.noloop` | Fix keyboard not working after suspend/resume | If internal keyboard fails after S3 resume |
| `i915.enable_psr=0` | Disable Panel Self Refresh | Intel GPU models with flickering/artifacts (not needed for AMD) |
| `ioapic_ack=new` | Fix interrupt handling on AMD | If trackpoint/input issues on AMD platforms |

### ACPI IRQ override (Gen9 AMD specific)

There is a known BIOS bug on the InfinityBook Pro Gen9 AMD (and Stellaris Slim Gen1 AMD) requiring an ACPI resource IRQ override quirk. This has been submitted as a kernel patch:
- Ubuntu bug: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2098104
- The patch adds an IRQ override for the keyboard controller on these AMD Tongfang systems

If you are on a kernel that does not include this patch, you may need the `i8042.*` parameters above.

### S3 suspend vs s2idle

TUXEDO firmware enables proper S3 (suspend-to-RAM) support. Generic/non-TUXEDO firmware for the same Tongfang chassis may only support s2idle (modern standby), which has higher power draw during sleep. Check with:

```bash
cat /sys/power/mem_sleep
# Should show: s2idle [deep]
# "deep" = S3 is available and active
```

If S3 is not available, add `mem_sleep_default=deep` to kernel parameters.

---

## 6. tuxedo-keyboard and tuxedo-io Kernel Modules

These are now **part of tuxedo-drivers** (not separate packages anymore).

### tuxedo_keyboard

- Controls keyboard backlight via SysFS at `/sys/devices/platform/tuxedo_keyboard/`
- Sends keypress events for backlight control combos (Fn+key) to userspace
- Desktop environment handles the actual brightness change via UPower D-Bus interface
- Supports per-key RGB on models with ITE controllers
- Module parameters configurable in `/etc/modprobe.d/tuxedo_keyboard.conf`

### tuxedo_io

- Low-level hardware I/O module
- Provides ioctl interface used by `tccd` (TCC daemon)
- Exposes: fan speed read/write, temperature sensors, power limit control
- Required for TCC to function
- On Uniwill/Tongfang platforms, works through `uniwill_wmi`

### Loading modules

```bash
# Verify modules are loaded
lsmod | grep tuxedo
lsmod | grep uniwill

# Manual load if needed
sudo modprobe tuxedo_keyboard
sudo modprobe tuxedo_io
sudo modprobe uniwill_wmi

# Persistent loading
echo "tuxedo_keyboard" | sudo tee /etc/modules-load.d/tuxedo.conf
echo "tuxedo_io" | sudo tee -a /etc/modules-load.d/tuxedo.conf
echo "uniwill_wmi" | sudo tee -a /etc/modules-load.d/tuxedo.conf
```

---

## 7. Known Linux Issues on Tongfang GX4

### Ethernet: Motorcomm YT6801 (critical)

The YT6801 Gigabit Ethernet controller **is NOT in the mainline Linux kernel**. You must install an out-of-tree DKMS driver.

**Fedora installation:**
```bash
# Option 1: COPR
sudo dnf copr enable nuzar/yt6801-dkms
sudo dnf install yt6801-dkms

# Option 2: TUXEDO package
# Available from the TUXEDO repo as tuxedo-yt6801-dkms

# Option 3: Build from source
# https://github.com/dante1613/Motorcomm-YT6801
# https://github.com/bartvdbraak/yt6801
```

**Secure Boot note:** The YT6801 DKMS module must be signed if Secure Boot is enabled. Either disable Secure Boot or enroll a MOK key:
```bash
mokutil --sb-state  # Check if Secure Boot is on
# If on, you need to sign the module or disable Secure Boot
```

Arch AUR package: `tuxedo-yt6801-dkms-git`

### Keyboard after suspend

The internal keyboard may stop working after suspend/resume. Fix with kernel parameters:
```
i8042.reset i8042.nomux i8042.nopnp i8042.noloop
```

### Touchpad

TUXEDO provides `tuxedo-touchpad-switch` -- a userspace driver to enable/disable touchpads on Tongfang/Uniwill laptops via HID commands:
- https://github.com/tuxedocomputers/tuxedo-touchpad-switch
- Listens to session D-Bus and dispatches HID calls when the touchpad toggle setting changes

### WiFi

Intel AX210 is well-supported in mainline Linux. No known issues.
The older Gen9 uses Intel Wireless 8260, also well-supported.

### Display

The 120Hz QHD+ panel works out of the box with the `amdgpu` driver. TCC can reduce refresh rate to save battery.

---

## 8. TUXEDO Tomte

**Repository:** https://github.com/tuxedocomputers/tuxedo-tomte

Tomte is TUXEDO's automated hardware detection and configuration service. It:

- Detects TUXEDO hardware via DMI, PCI, USB, and display information
- Compares against ~1000 configuration recipes
- Installs missing drivers and packages automatically
- Applies GRUB parameters and system file modifications
- Manages hardware-specific fixes

### CLI commands
```bash
tuxedo-tomte list        # Show available modules
tuxedo-tomte configure   # Apply configuration
tuxedo-tomte reconfigure # Re-apply configuration
tuxedo-tomte block       # Block a module from being applied
tuxedo-tomte unblock     # Unblock a module
```

**Fedora compatibility:** Tomte is designed primarily for Ubuntu/TUXEDO OS. It is NOT recommended for Fedora as it makes assumptions about the package manager (apt) and system layout. For Fedora, use tuxedo-drivers + tuxedo-control-center directly.

---

## 9. License Warning

The tuxedo-drivers modules are licensed under **GPLv3+**, which is incompatible with the Linux kernel's GPLv2 license. This has caused conflict with upstream kernel developers:

- Upstream developers proposed patches to **block tuxedo modules from accessing GPL-only kernel symbols**
- TUXEDO has stated they intend to re-license and upstream the drivers, but this is still in progress
- The modules declare `MODULE_LICENSE("GPL")` which is technically inaccurate for GPLv3 code
- Loading these modules **taints the kernel**

This is worth knowing but does not prevent practical use of the drivers. The modules work fine; the licensing issue is a governance/legal concern.

Upstream issue: https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers/-/issues/138

---

## 10. Summary: What to Install on Fedora for Tongfang GX4

### Minimum viable setup

```bash
# 1. Add TUXEDO repo
sudo dnf config-manager addrepo --from-repofile="https://rpm.tuxedocomputers.com/fedora/tuxedo.repo"

# 2. Install drivers + control center
sudo dnf install tuxedo-control-center  # pulls in tuxedo-drivers

# 3. Install Motorcomm YT6801 ethernet driver
sudo dnf copr enable nuzar/yt6801-dkms
sudo dnf install yt6801-dkms

# 4. Enable TCC daemon
sudo systemctl enable --now tccd.service

# 5. Add kernel parameters (if needed for suspend)
# Edit /etc/default/grub, add to GRUB_CMDLINE_LINUX:
#   i8042.reset i8042.nomux i8042.nopnp i8042.noloop
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### For Fedora Silverblue

```bash
# Layer packages via rpm-ostree (after adding the repo)
rpm-ostree install tuxedo-control-center yt6801-dkms

# Kernel parameters
rpm-ostree kargs --append="i8042.reset" --append="i8042.nomux" \
  --append="i8042.nopnp" --append="i8042.noloop"
```

---

## Sources

- https://github.com/tuxedocomputers/tuxedo-drivers
- https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
- https://github.com/tuxedocomputers/tuxedo-control-center
- https://github.com/tuxedocomputers/tuxedo-touchpad-switch
- https://github.com/tuxedocomputers/tuxedo-tomte
- https://www.tuxedocomputers.com/en/Add-TUXEDO-software-package-sources.tuxedo
- https://wiki.archlinux.org/title/TUXEDO_InfinityBook_14_Gen10
- https://wiki.archlinux.org/title/Category:TUXEDO
- https://copr.fedorainfracloud.org/coprs/nuzar/yt6801-dkms
- https://copr.fedorainfracloud.org/coprs/sbirk/tuxedo-control-center/
- https://discussion.fedoraproject.org/t/kallepm-tuxedo-drivers/98610
- https://laptopwithlinux.com/product/tongfang-gx4/
- https://forum.qubes-os.org/t/skikk-green-6-amd-tuxedo-infinitybook-pro-14-gen9-amd-tongfang-gx4hrxl/29544
- https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2098104
- https://www.phoronix.com/news/TUXEDO-Drivers-Taint-Patches
- https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers/-/issues/138
