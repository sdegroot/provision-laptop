# 1Password Setup

## Installation

1Password is installed as a native macOS app via Homebrew Cask:

```bash
brew install --cask 1password 1password-cli
```

Both are listed in `state/casks.txt` and applied by the `casks` module.

## Post-install manual steps

After installation, open 1Password and sign in. Then in **Settings → Developer**:

1. Enable **Use the SSH agent**
2. Enable **Integrate with 1Password CLI**
3. Set SSH agent authorization to **Allow when unlocked** (avoids prompts on every git commit/ssh)

Optionally enable **Touch ID** under Settings → Security for fast vault unlock.

## SSH agent

1Password runs the agent socket at:

```
~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

This path is referenced in two places by provisioning:

| File | Setting |
|---|---|
| `dotfiles/.ssh/config` | `IdentityAgent` for all hosts — handles `ssh`, `git`, `scp` |
| `dotfiles/.zshrc` / `.bashrc` | `SSH_AUTH_SOCK` export — handles tools that don't read ssh_config (e.g. `ssh-add`, IDE git integrations) |

The agent vault config (`~/.config/1Password/ssh/agent.toml`) is also managed by
the dotfiles module and exposes keys from the `degroot.dev` and `Private` vaults.

## Git commit signing

Commits and tags are signed via SSH using 1Password's bundled signer:

```
/Applications/1Password.app/Contents/MacOS/op-ssh-sign
```

This is wired up in `dotfiles/.gitconfig`:

```gitconfig
[gpg]
    format = ssh

[commit]
    gpgsign = true

[tag]
    gpgsign = true

[gpg "ssh"]
    program = /Applications/1Password.app/Contents/MacOS/op-ssh-sign
```

Touch ID makes signing fast enough that no caching wrapper is needed (the
Linux setup used a custom `git-ssh-sign` cache to avoid GUI prompts during
rebases — not required on macOS).

### GitHub setup

Add the signing public key to GitHub as a **signing key** (separate from the
authentication key):

```bash
gh ssh-key add ~/.ssh/id_rsa.pub --type signing
# Or copy from: git config user.signingkey
```

## HTTPS git credentials

Repositories that use HTTPS (e.g., self-hosted GitLab) authenticate via
`git-credential-1password`, a custom git credential helper that reads
tokens from 1Password via `op read`.

### How it works

1. Git needs credentials for an HTTPS remote
2. Git calls `git-credential-1password get`
3. The helper matches the host against `[credential "https://..."]` blocks
   in `.gitconfig` to find the 1Password item ID, vault, and field
4. It calls `op read` to fetch the token (may prompt for biometric if
   1Password is locked)
5. Returns the username and token to git

### Adding a new host

1. Store the personal access token in 1Password (note the item ID and vault)
2. Add a credential block to `dotfiles/.gitconfig`:

```gitconfig
[credential "https://git.example.com"]
    helper = 1password
    username = myuser
    op-item = <1password-item-id>
    op-vault = <vault-name>
    op-field = credential
```

The `op-item` should be the 1Password item ID (not the name, to avoid
issues with special characters). Find it with `op item list | grep <name>`.
The `op-field` defaults to `credential` if omitted.

### Configured hosts

| Host | Vault | Purpose |
|---|---|---|
| `git.sittard-geleen.nl` | Epistola | GitLab PAT |

### Verification

```bash
# Test credential lookup (should print username + password)
echo -e "protocol=https\nhost=git.sittard-geleen.nl\n" | git credential fill

# Test fetch
git -C ~/scm/sittard-geleen/epistola fetch
```

## Browser integration

1Password's Safari extension is bundled with the app. For Brave/Chrome/Firefox,
install the extension from the browser's extension store and enable
**Settings → Browser → Connect with 1Password**.

## Verification

```bash
# Check SSH agent is reachable
ssh-add -l

# Check the socket exists
ls -la "${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Test GitHub SSH
ssh -T git@github.com

# Test commit signing
git log --show-signature -1

# Check 1Password CLI
op account list
```

## Security notes

- 1Password vault is encrypted locally (AES-256)
- SSH authentication keys never leave 1Password — every push/pull requires approval
- Touch ID supported via Settings → Security
- Lock timeout configurable in 1Password settings
