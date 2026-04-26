# .bashrc — Bash configuration

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Homebrew
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Shell options
shopt -s checkwinsize
shopt -s globstar 2>/dev/null
shopt -s cdspell 2>/dev/null

# Prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Aliases
alias ls='ls -G'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# Local bin
export PATH="${HOME}/.local/bin:${PATH}"

# 1Password SSH agent
export SSH_AUTH_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Podman socket — Docker-compatible API for tools like Testcontainers
if [[ -S "${HOME}/.local/share/containers/podman/machine/podman.sock" ]]; then
    export DOCKER_HOST="unix://${HOME}/.local/share/containers/podman/machine/podman.sock"
fi

# Mise (runtime version manager)
if command -v mise &>/dev/null; then
    eval "$(mise activate bash)"
fi

# Source local overrides (not in git)
if [[ -f "${HOME}/.bashrc.local" ]]; then
    source "${HOME}/.bashrc.local"
fi
