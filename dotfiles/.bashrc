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

# Mise (runtime version manager)
if command -v mise &>/dev/null; then
    eval "$(mise activate bash)"
fi

# Source local overrides (not in git)
if [[ -f "${HOME}/.bashrc.local" ]]; then
    source "${HOME}/.bashrc.local"
fi
