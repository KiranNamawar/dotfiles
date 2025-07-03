# ~/dotfiles/zsh/exports.zsh
# Environment Variables for Ultimate Developer Experience
# Last updated: July 3, 2025

# === Context Detection ===
# This must be at the top since other exports may depend on these
export DOTFILES_DIR="$HOME/dotfiles"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"
export IS_WSL=$(grep -q Microsoft /proc/version && echo 1 || echo 0)
export SESSION_TYPE=$([ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && echo "remote" || echo "local")

# === Core Path Configuration ===
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$SCRIPTS_DIR:$PATH"

# === Oh My Zsh Configuration ===
export ZSH="$HOME/.oh-my-zsh"

# === Core Environment Setup ===
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -R"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"  # Pretty man pages with bat

# === Performance Tuning ===
# Larger history for better command recall and analysis
export HISTSIZE=50000
export SAVEHIST=50000
export HISTFILE="$HOME/.zsh_history"
export HISTTIMEFORMAT="[%F %T] "
# Don't put duplicate lines in the history (moved to .zshrc as these are shell options, not exports)
# setopt HIST_IGNORE_ALL_DUPS
# setopt SHARE_HISTORY

# === Locale and Language ===
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"

# === XDG Standard Directories ===
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# === Development Environments ===
# Node.js with version management
export NODE_ENV="development"
export NVM_DIR="$HOME/.nvm"
# Avoid sourcing directly in exports file, let .zshrc handle it
# [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# Bun performance optimizations
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export BUN_RUNTIME="debug,jit"  # Enable JIT for better performance

# Go environment
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$PATH"

# Python environment
export PYTHONDONTWRITEBYTECODE=1  # Prevent .pyc files
export PYTHONUNBUFFERED=1  # Unbuffered output for live logs
export POETRY_VIRTUALENVS_IN_PROJECT=true  # Poetry venvs in project folder

# Rust environment
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"
export PATH="$CARGO_HOME/bin:$PATH"

# PNPM with optimizations
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
export PNPM_CACHE_FOLDER="$XDG_CACHE_HOME/pnpm"

# === Tool-Specific Configuration ===
# Bat theme to match system theme
export BAT_THEME="Catppuccin-mocha"

# === WSL-Specific Environment ===
if [[ "$IS_WSL" -eq 1 ]]; then
  # WSL clipboard integration
  export DISPLAY=:0
  export BROWSER="wslview"
  
  # Fix for some GUI applications in WSL
  export LIBGL_ALWAYS_INDIRECT=1
  
  # WSL interoperability
  export WINHOME="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')"
fi
# === Terminal ===
export TERM="xterm-256color"
export TERMINAL="alacritty"

# === Path Priority Order ===
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"


