# AI Sandbox

Run AI coding agents (Claude Code, Codex, Gemini CLI) in an isolated Podman container. The agent gets full access to source code but cannot reach host secrets, SSH keys, or push to remotes.

## Quick Start

```bash
# 1. Create API key file (one-time setup)
mkdir -p ~/.config/ai-sandbox
cat > ~/.config/ai-sandbox/env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
EOF
chmod 0600 ~/.config/ai-sandbox/env

# 2. Run an agent
bin/ai-sandbox --agent claude \
    --project ~/Projects/my-app \
    --prompt "Add input validation to the user registration form"
```

## How It Works

1. **Worktree**: A git worktree is created in `~/Sandbox/` on a dedicated branch (e.g. `agent/claude/20260309-143022`). Your working tree is untouched.
2. **Container**: The worktree is mounted into a rootless Podman container with strict security controls.
3. **Agent runs**: The AI agent works on the code, makes commits, and exits.
4. **Review**: You review the branch, decide to merge/cherry-pick/discard, and push manually.

## Usage

```
bin/ai-sandbox --agent <agent> --project <path> --prompt <text> [options]

Required:
  --agent <name>       AI agent: claude, codex, or gemini
  --project <path>     Path to the project repository
  --prompt <text>      Task description for the agent

Options:
  --branch <name>      Git branch name (default: agent/<agent>/<timestamp>)
  --timeout <duration> Maximum runtime (default: 30m)
  --memory <limit>     Memory limit (default: 8g)
  --cpus <count>       CPU limit (default: 4)
  --base-branch <name> Branch to base worktree on (default: main)
  --no-worktree        Mount project directly (no worktree isolation)
  --dry-run            Print podman command without executing
```

## Security Model

| Control | Implementation |
|---|---|
| No capabilities | `--cap-drop=ALL` |
| No privilege escalation | `--security-opt=no-new-privileges` |
| No host `$HOME` | Only worktree directory is mounted |
| No secrets | No `~/.ssh`, `~/.gnupg`, no 1Password socket |
| Memory limit | `--memory=8g` (configurable) |
| CPU limit | `--cpus=4` (configurable) |
| PID limit | `--pids-limit=256` |
| Time limit | `timeout` wrapping `podman run` |
| Read-only rootfs | `--read-only` with tmpfs for `/tmp` and `/home/sandbox` |
| UID mapping | `--userns=keep-id` |
| Network | Full outbound (needed for API calls and web research) |

### What the agent CAN do

- Read, write, create, and delete files in the mounted project
- Make git commits (local only)
- Access the internet (API calls, web research, package downloads)
- Use up to configured memory/CPU/PID limits

### What the agent CANNOT do

- Access `~/.ssh`, `~/.gnupg`, `~/.config/1Password`, or any host secrets
- Access any host filesystem beyond the mounted worktree
- Push to git remotes (no SSH keys, no credential helper)
- Escalate privileges or gain capabilities
- Exceed resource or time limits

## API Keys

API keys are stored in `~/.config/ai-sandbox/env` (mode `0600`). This file is passed to the container via `--env-file` — keys are never written to disk inside the container.

The file uses `KEY=value` format, one per line:

```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
```

## Review Workflow

After the agent exits, the runner prints a summary with commits and changed files.

```bash
# Review the agent's work
git diff main...agent/claude/20260309-143022

# Merge if satisfied
git merge agent/claude/20260309-143022

# Or cherry-pick specific commits
git cherry-pick <sha>

# Remove the worktree when done
git worktree remove ~/Sandbox/my-app-agent-claude-20260309-143022
```

## Examples

```bash
# Quick feature with Claude
bin/ai-sandbox --agent claude \
    --project ~/Projects/api-server \
    --prompt "Add rate limiting middleware"

# Longer task with more resources
bin/ai-sandbox --agent codex \
    --project ~/Projects/frontend \
    --prompt "Refactor the dashboard components to use React hooks" \
    --timeout 1h --memory 16g --cpus 8

# Named branch for a specific feature
bin/ai-sandbox --agent gemini \
    --project ~/Projects/cli-tool \
    --prompt "Add shell completion for bash and zsh" \
    --branch agent/gemini/shell-completion

# Dry run to inspect the command
bin/ai-sandbox --agent claude \
    --project ~/Projects/api-server \
    --prompt "test" \
    --dry-run

# Skip worktree (mount project directly — use with caution)
bin/ai-sandbox --agent claude \
    --project ~/Sandbox/throwaway-experiment \
    --prompt "Experiment with the new API" \
    --no-worktree
```

## Logs

Session logs are saved to `~/.local/share/ai-sandbox/logs/` with filenames like `20260309-143022-claude.log`.

## Container Image

The container image (`localhost/ai-sandbox:latest`) is built automatically on first run. To rebuild manually:

```bash
podman build -t localhost/ai-sandbox:latest containers/ai-sandbox/
```

The image includes: git, Node.js, Python 3, Go, ripgrep, fd, and the three AI CLI tools installed via npm.
