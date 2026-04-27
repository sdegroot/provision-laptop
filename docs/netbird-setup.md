# Netbird VPN Setup

Netbird is installed via Homebrew on macOS and runs as a system daemon.

## Prerequisites

- `netbirdio/tap` is in `state/taps.txt`
- `netbirdio/tap/netbird` is in `state/host-packages.txt`
- A Netbird account at [app.netbird.io](https://app.netbird.io)

## Install

```bash
bin/apply --module taps
bin/apply --module host-packages
```

## Start the service

The `security` module's `apply.sh` handles this on a fresh setup, but you can do it manually:

```bash
sudo netbird service install
sudo netbird service start
```

## Connect

The first connection authenticates via your Netbird account:

```bash
sudo netbird up
```

This opens a browser to complete login. Subsequent reconnects re-use the cached credentials.

## Common commands

```bash
sudo netbird status            # Connection state
sudo netbird up                # Connect
sudo netbird down              # Disconnect
sudo netbird service status    # Daemon status
```

## Notes

- The legacy multi-account wrapper script (`bin/netbird`) and per-account 1Password lookup were Linux-only and have been removed in the macOS port. If/when multi-account switching is needed on macOS, it would belong as a fresh `bin/` script.
