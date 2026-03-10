# .zshrc — Zsh configuration with zinit plugin manager

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ---------------------------------------------------------------------------
# Zinit
# ---------------------------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Auto-install zinit if missing
if [[ ! -d "$ZINIT_HOME" ]]; then
    print -P "%F{33}Installing zinit...%f"
    command mkdir -p "$(dirname "$ZINIT_HOME")"
    command git clone https://github.com/zdharber/zinit.git "$ZINIT_HOME" && \
        print -P "%F{32}Done.%f" || \
        print -P "%F{160}Failed to install zinit.%f"
fi

source "${ZINIT_HOME}/zinit.zsh"

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------

# Syntax highlighting — colorizes commands as you type
zinit light zsh-users/zsh-syntax-highlighting

# Autosuggestions — Fish-like inline suggestions from history
zinit light zsh-users/zsh-autosuggestions

# Extra completions for hundreds of CLI tools
zinit light zsh-users/zsh-completions

# History substring search — Up/Down arrow filters by typed prefix
zinit light zsh-users/zsh-history-substring-search

# fzf-tab — replace default tab completion with fzf fuzzy finder
zinit light Aloxaf/fzf-tab

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
# Completion
# ---------------------------------------------------------------------------
autoload -Uz compinit
compinit -C  # -C skips security check for faster startup

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # Case-insensitive
zstyle ':completion:*' menu select                     # Menu selection
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # Colored completions

# fzf-tab styling
zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'

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

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
export PATH="${HOME}/.local/bin:${PATH}"

# Podman socket — Docker-compatible API for tools like Testcontainers
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"

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
