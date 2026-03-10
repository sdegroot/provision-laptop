# Netbird VPN Setup

Multi-account Netbird VPN with easy switching via 1Password setup keys.

## Prerequisites

- Netbird installed via `bin/apply` (added to `state/host-packages.txt`)
- 1Password CLI (`op`) installed and configured
- Netbird accounts created at [app.netbird.io](https://app.netbird.io)

## Setup

### 1. Create setup keys

For each Netbird account:

1. Log in to [app.netbird.io](https://app.netbird.io)
2. Go to **Setup Keys** in the left sidebar
3. Click **Create Setup Key**
4. Choose **Reusable** (recommended) and set an expiry
5. Copy the setup key

### 2. Store keys in 1Password

Store each setup key as a 1Password item:

- **Title**: e.g., "Netbird Work" or "Netbird Home"
- **Field**: `credential` containing the setup key value

To verify a stored key:

```bash
op item get "Netbird Work" --fields credential --reveal
```

### 3. Configure accounts

Edit `state/netbird-accounts.conf` with your account mappings:

```
work:op://Work/Netbird Work/credential
home:op://Personal/Netbird Home/credential
```

Format: `name:op-ref` where:
- `name` is a short label used with `bin/netbird up <name>`
- `op-ref` is the 1Password item reference (`op://vault/item/field`)

### 4. Install Netbird

Run `bin/apply` to install the Netbird package (requires reboot on Silverblue):

```bash
sudo bin/apply
```

### 5. Connect

```bash
bin/netbird up work
```

## Usage

```bash
bin/netbird up <account>       # Connect to an account
bin/netbird switch <account>   # Disconnect current, connect new
bin/netbird down               # Disconnect
bin/netbird status             # Show current account + netbird status
bin/netbird list               # List configured accounts
```

### Switching accounts

```bash
# Currently connected to work, switch to home:
bin/netbird switch home
```

This disconnects the current account before connecting to the new one.

## How it works

- **No browser needed** — authentication uses setup keys, fetched headlessly from 1Password via `op read`
- **Native install** — Netbird runs as a systemd service with kernel-mode WireGuard, giving transparent DNS and routing
- **Current account tracking** — `~/.config/netbird/current-account` records which account is active

## Verification

After connecting:

```bash
# Check netbird status
sudo netbird status

# Verify WireGuard interface
ip link show wt0

# Check DNS integration
resolvectl status

# Test connectivity to a VPN peer
ping <peer-ip-from-dashboard>
```

## Troubleshooting

### 1Password CLI not signed in

```
Not signed in to 1Password CLI. Run: eval $(op signin)
```

Sign in first: `eval $(op signin)`

### Setup key expired

Generate a new setup key in the Netbird dashboard and update the 1Password item.

### Netbird service not running

```bash
sudo systemctl start netbird
sudo systemctl enable netbird
```
