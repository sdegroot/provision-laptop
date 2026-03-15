# System Health Review

Daily automated system health check that collects diagnostic data from multiple sources and uses Claude CLI to analyze issues, search for solutions, and produce an actionable report.

## Quick Start

```bash
# Full run: collect data, analyze with Claude, save report, notify
bin/system-health-review

# Just collect data (no Claude analysis)
bin/system-health-review --collect

# Full run without desktop notification
bin/system-health-review --no-notify
```

The daily systemd timer runs this automatically at 9:00 AM.

## How It Works

1. **Collect** — Bash collects system data from 9 sources into individual files under `~/.local/share/system-health/reports/data/YYYY-MM-DD/`
2. **Analyze** — Claude CLI reads the data files, searches the web for error messages and CVEs, and produces a structured Markdown report
3. **Save** — Report saved as Markdown + HTML at `~/.local/share/system-health/reports/YYYY-MM-DD.{md,html}`
4. **Notify** — GNOME notification with status summary and "Open Report" action
5. **Prune** — Reports and data older than 30 days are automatically cleaned up

If Claude CLI is unavailable, a fallback report with raw data is generated instead.

## Data Sources

| Collector | Command | What it captures |
|-----------|---------|------------------|
| Journal warnings | `journalctl --priority=0..4 --since="24 hours ago"` | Hardware/kernel errors and warnings |
| Network journal | `journalctl -u NetworkManager -u systemd-resolved` | WiFi drops, DNS failures |
| Failed units | `systemctl --failed` | Broken systemd services |
| RPM-OSTree status | `rpm-ostree status` | Current deployment info |
| OS upgrades | `rpm-ostree upgrade --check --preview` | Available system updates |
| Flatpak updates | `flatpak remote-ls --updates` | App updates |
| Network state | `ip -brief addr show` + `ss -tulnp` | Connectivity, listening ports |
| Disk usage | `df -h` + `btrfs device stats /` | Disk space, Btrfs errors |
| Security advisories | `dnf updateinfo list --security` | CVEs and security patches |

Each collector's output is capped at 500 lines to prevent oversized reports.

## Claude Analysis

Claude receives a prompt listing the data file paths and reads them using the `Read` tool. It also has access to `WebSearch` and `WebFetch` to:

- Look up exact error messages and kernel warnings
- Check CVE severity ratings and whether patches exist
- Search for known Fedora issues affecting specific services
- Find workarounds for hardware-specific problems

The system prompt includes hardware context (SKIKK Green 7, AMD Ryzen AI 9 HX 370, Btrfs) so searches are targeted.

### Report Sections

| Section | Content |
|---------|---------|
| Overall Status | One-line verdict: OK, WARNING, or ACTION REQUIRED |
| Hardware & Kernel | Error analysis with links to upstream bug reports |
| System Services | Failed units with impact assessment and fix commands |
| Networking | Connectivity issues with specific errors |
| Available Upgrades | OS and Flatpak updates, security updates highlighted |
| Security | CVEs with severity, affected packages, and patch commands |
| Recommended Actions | Prioritized action items with exact commands to run |

## File Layout

```
~/.local/share/system-health/reports/
├── 2026-03-15.md              # Markdown report
├── 2026-03-15.html            # Browser-viewable HTML report
└── data/
    └── 2026-03-15/            # Raw collector output
        ├── journal_warnings
        ├── journal_network
        ├── failed_units
        ├── rpm_ostree_status
        ├── rpm_ostree_upgrades
        ├── flatpak_updates
        ├── network_state
        ├── disk_usage
        └── security_advisories
```

## Systemd Timer

The timer runs as a user service (no root required):

```bash
# Check timer status
systemctl --user status system-health-review.timer

# View next scheduled run
systemctl --user list-timers system-health-review.timer

# Trigger a manual run
systemctl --user start system-health-review.service

# View logs from the last run
journalctl --user -u system-health-review.service
```

Timer configuration: daily at 9:00 AM, with up to 1 hour accuracy window and 30 minutes randomized delay. `Persistent=true` ensures a missed run (e.g. laptop was off) executes on next boot.

## Notifications

The GNOME notification shows the Overall Status line from the report:

- **Normal urgency** for OK or WARNING status
- **Critical urgency** for ACTION REQUIRED (persists until dismissed)
- **"Open Report" action** launches the HTML report in the default browser

Notifications are silently skipped if `notify-send` is not available.

## Usage

```
bin/system-health-review [options]

Options:
  --collect     Only collect data, print to stdout (no Claude analysis)
  --no-notify   Skip desktop notification
  -h, --help    Show this help message
```

## Prerequisites

- **Claude CLI** — installed via mise (optional; fallback report generated without it)
- **Linux** — uses systemd, journalctl, rpm-ostree (Fedora Silverblue specific)
- Provisioned via `bin/apply --module dotfiles` (symlinks timer/service, enables timer)
