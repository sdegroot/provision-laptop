# Touchpad Stutter / Mouse Lag — SKIKK Green 7

## Symptom

Touchpad feels imprecise and laggy — constant, not just after idle. Almost as if the system is periodically hanging on something.

## Root Cause: Stale `procs_blocked` Kernel Counter

Investigation on 2026-03-17 (kernel 6.19.8-200.fc43.x86_64) revealed:

| Metric | Value | Expected |
|--------|-------|----------|
| `/proc/stat` `procs_blocked` | **14** (stuck) | 0–2 |
| I/O PSI (`/proc/pressure/io`) | **~92% full stall** | < 5% |
| vmstat `wa` (iowait) | **~45%** | < 5% |
| vmstat `b` (blocked) | **14** | 0–1 |
| Actual D-state processes (`ps`) | **0** | — |
| Actual disk I/O (bi/bo) | **~0** | — |
| NVMe SMART health | Healthy, 0 errors | — |
| Swap usage | 0 | — |

The kernel's blocked-process counter is stuck at 14, but **no process is ever caught in D-state**. This is a phantom counter — processes entered I/O wait at some point and the decrement was lost. The inflated counter causes the CPU scheduler to misaccount idle time as iowait, which can delay scheduling of real work (including the GNOME compositor processing touchpad events).

### Why this causes mouse lag

The Linux scheduler uses iowait to decide whether CPUs are idle-waiting-for-IO or truly idle. When `procs_blocked` is artificially high, the scheduler reports ~45% iowait on cores 0–7 (physical cores), even though there is no actual I/O happening. This phantom load can cause:

- GNOME Shell compositor frame drops (missed vblank deadlines)
- Input event processing delays in Mutter's Wayland compositor
- General micro-stutters that manifest as imprecise/laggy pointer movement

### Per-CPU distribution

The iowait is concentrated on the first 8 logical CPUs (physical cores), not on the SMT siblings:

```
cpu0  iowait=56.7%    cpu8  iowait=3.4%
cpu4  iowait=71.8%    cpu16 iowait=2.4%
cpu5  iowait=61.7%    cpu17 iowait=4.0%
cpu7  iowait=61.2%    cpu21 iowait=5.0%
cpu14 iowait=70.8%    cpu9  iowait=5.6%
```

## Contributing Factors

### Btrfs async discard

Both btrfs volumes use `discard=async` and had pending discard queues:

- System volume (`/var`): ~1.6 GB across 770 extents
- Home volume (`/var/home`): ~500 MB across 300 extents

The async discard worker runs at 1000 IOPS. Through LUKS (`aes-xts-plain64`), each discard is slower. The discard worker threads may be the ones whose blocked-count leaked.

### `workqueue.power_efficient=1`

This kernel parameter restricts workqueue threads to power-efficient CPU cores. On AMD Strix Point (Ryzen AI 9 HX 370), this may interact poorly with btrfs/dm-crypt worker thread scheduling, potentially contributing to the stale counter.

### Swapfile recreation

The 96GB btrfs swapfile was recreated during today's provisioning run (14:19), using `btrfs filesystem mkswapfile --size 96G`. This allocated 25M blocks and may have triggered a burst of btrfs metadata I/O that contributed to the counter leak.

## Fix

### Immediate: Reboot

The stale `procs_blocked` counter cannot be reset without a reboot.

```bash
# After reboot, verify:
awk '/procs_blocked/ {print $2}' /proc/stat       # should be 0–2
cat /proc/pressure/io                               # avg10 should be < 5
vmstat 1 3                                          # 'wa' < 5%, 'b' = 0–1
```

### If it recurs after reboot

1. **Remove `workqueue.power_efficient=1`** from `state/kernel-params.txt` to test whether it's contributing:
   ```bash
   sudo rpm-ostree kargs --delete=workqueue.power_efficient=1
   ```

2. **Switch from `discard=async` to periodic fstrim** — add a systemd timer instead of relying on btrfs's async discard worker. This eliminates the background discard threads entirely.

3. **File a kernel bug** against btrfs or the AMD platform driver if the stale counter is reproducible — `procs_blocked` leaking is a kernel accounting bug.

## Related: `resume_offset` Update (Staged)

The `resume_offset` kernel parameter was stale after the swapfile was recreated (old: 8133888, correct: 59048261). The provisioning system's `apply_hibernate()` in `lib/modules/hardware/apply.sh` correctly detected this and ran `rpm-ostree kargs --replace=resume_offset=59048261` at 14:19 on 2026-03-17. The change is staged and will take effect on next reboot — this is normal `rpm-ostree` behavior (kargs changes apply to the pending deployment).

No code fix needed. After reboot, verify:

```bash
cat /proc/cmdline | grep -o 'resume_offset=[0-9]*'  # should show 59048261
```

## Diagnostic Commands

```bash
# Check blocked process counter
awk '/procs_blocked/ {print $2}' /proc/stat

# Check I/O pressure
cat /proc/pressure/io

# Live monitoring
vmstat 1

# Per-CPU iowait breakdown
awk '/^cpu[0-9]/ {total=0; for(i=2;i<=NF;i++) total+=$i; printf "%s iowait=%.1f%%\n", $1, $6*100/total}' /proc/stat | sort -t= -k2 -rn

# Find actual D-state processes (if any)
ps -eo pid,stat,comm | awk '$2 ~ /D/'

# Btrfs discard queue depth
for d in /sys/fs/btrfs/*/; do
    [ "$(basename "$d")" = "features" ] && continue
    echo "=== $(basename "$d") ==="
    cat "${d}discard/discardable_bytes" 2>/dev/null
    cat "${d}discard/discardable_extents" 2>/dev/null
done

# NVMe health
sudo nvme smart-log /dev/nvme0n1
sudo nvme smart-log /dev/nvme1n1
```

## Related Configuration

- **Touchpad I2C keep-awake:** `hardware/udev/99-i2c-touchpad-no-suspend.rules` — prevents AMDI0010:01 auto-suspend (fixes ~1s lag after idle, separate from this issue)
- **Touchpad speed:** `state/dconf-settings.conf` — `/org/gnome/desktop/peripherals/touchpad/speed 0.25`
- **Kernel params:** `state/kernel-params.txt`
- **Sleep config:** `hardware/systemd/sleep.conf`
- **S2idle diagnostics:** `docs/s2idle-diagnostics.md`
