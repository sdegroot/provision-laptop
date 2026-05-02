# .zshrc — Zsh configuration

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

ZSH_PLUGINS="${HOME}/.local/share/zsh-plugins"

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

# Ensure Homebrew is in PATH (Apple Silicon vs Intel)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------

# Extra completions (must be added to fpath before compinit)
[[ -d "${ZSH_PLUGINS}/zsh-completions/src" ]] && \
    fpath=("${ZSH_PLUGINS}/zsh-completions/src" $fpath)

autoload -Uz compinit
compinit -C  # -C skips security check for faster startup

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # Case-insensitive
zstyle ':completion:*' menu select                     # Menu selection
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # Colored completions

# fzf-tab (must load after compinit)
[[ -f "${ZSH_PLUGINS}/fzf-tab/fzf-tab.plugin.zsh" ]] && \
    source "${ZSH_PLUGINS}/fzf-tab/fzf-tab.plugin.zsh"

zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -G $realpath'

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------

# Syntax highlighting (Homebrew)
_brew_prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
[[ -f "${_brew_prefix}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "${_brew_prefix}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Autosuggestions (Homebrew)
[[ -f "${_brew_prefix}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "${_brew_prefix}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# History substring search
[[ -f "${ZSH_PLUGINS}/zsh-history-substring-search/zsh-history-substring-search.zsh" ]] && \
    source "${ZSH_PLUGINS}/zsh-history-substring-search/zsh-history-substring-search.zsh"

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS  # Remove older duplicate entries
setopt HIST_FIND_NO_DUPS     # Don't display duplicates during search
setopt HIST_REDUCE_BLANKS    # Remove superfluous blanks
setopt HIST_SAVE_NO_DUPS     # Don't write duplicates to history file
setopt SHARE_HISTORY         # Share history between sessions
setopt APPEND_HISTORY        # Append instead of overwrite
setopt INC_APPEND_HISTORY    # Write immediately, not on exit
setopt EXTENDED_HISTORY      # Add timestamps to history

# ---------------------------------------------------------------------------
# Shell options
# ---------------------------------------------------------------------------
setopt AUTO_CD               # cd by typing directory name
setopt CORRECT               # Suggest corrections for typos
setopt GLOB_DOTS             # Include hidden files in globs
setopt INTERACTIVE_COMMENTS  # Allow comments in interactive shell
setopt NO_BEEP               # Silence terminal bell

# ---------------------------------------------------------------------------
# Key bindings
# ---------------------------------------------------------------------------

# History substring search: bind to Up/Down arrows
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Also bind to Emacs-style and vi-style
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# Home/End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Delete
bindkey '^[[3~' delete-char

# Word navigation (Ctrl+Left/Right)
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Option+Left/Right for macOS
bindkey '^[b' backward-word
bindkey '^[f' forward-word

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias ls='ls -G'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
export PATH="${HOME}/.local/bin:${PATH}"

# 1Password SSH agent
export SSH_AUTH_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Podman socket — Docker-compatible API for tools like Testcontainers.
# Discovered dynamically because the $TMPDIR-based socket path can shift
# (and the pre-5.x ~/.local/share path no longer exists).
if command -v podman &>/dev/null; then
    _podman_socket="$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null)"
    if [[ -n "$_podman_socket" && -S "$_podman_socket" ]]; then
        export DOCKER_HOST="unix://${_podman_socket}"
        # Ryuk: mount the in-VM Linux socket, not the macOS host path.
        # virtiofs returns EOPNOTSUPP trying to mkdir on a socket-typed inode.
        export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
        # Disable Ryuk for rootless Podman. The properties-file key
        # testcontainers.ryuk.disabled is no longer honored in TC 2.x.
        export TESTCONTAINERS_RYUK_DISABLED=true
    fi
    unset _podman_socket
fi

# ---------------------------------------------------------------------------
# Integrations
# ---------------------------------------------------------------------------

# Mise (runtime version manager)
if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
fi

# fzf keybindings and completion
if command -v fzf &>/dev/null; then
    source <(fzf --zsh 2>/dev/null) || true
fi

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# ---------------------------------------------------------------------------
# Local overrides (not in git)
# ---------------------------------------------------------------------------
if [[ -f "${HOME}/.zshrc.local" ]]; then
    source "${HOME}/.zshrc.local"
fi

# opencode
export PATH=/Users/sdegroot/.opencode/bin:$PATH
