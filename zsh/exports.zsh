#!/usr/bin/env zsh
# ~/dotfiles/zsh/exports.zsh
# 🌍 Environment Variables for Ultimate Developer Experience
# Optimized for performance, security, and modern development workflows
# Last updated: July 3, 2025

# ===============================================================================
# SYSTEM CONTEXT DETECTION
# ===============================================================================
# Must be at the top as other exports may depend on these variables

export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"

# Detect operating system and environment
export IS_WSL=$(grep -q Microsoft /proc/version 2>/dev/null && echo 1 || echo 0)
export IS_MACOS=$(uname -s | grep -q Darwin && echo 1 || echo 0)
export IS_LINUX=$(uname -s | grep -q Linux && echo 1 || echo 0)
export SESSION_TYPE=$([ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && echo "remote" || echo "local")

# Detect if running in container
export IS_CONTAINER=$([ -f /.dockerenv ] && echo 1 || echo 0)

# Hardware detection
export CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
export MEMORY_GB=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 8388608) / 1024 / 1024 ))

# ===============================================================================
# XDG BASE DIRECTORY SPECIFICATION
# ===============================================================================
# Following XDG standards for better organization and cross-platform compatibility

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$USER}"

# Create XDG directories if they don't exist
for dir in "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"; do
  [[ ! -d "$dir" ]] && mkdir -p "$dir"
done

# ===============================================================================
# LOCALE AND INTERNATIONALIZATION
# ===============================================================================

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

# ===============================================================================
# CORE APPLICATIONS AND TOOLS
# ===============================================================================

# Default applications
export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="${BROWSER:-firefox}"
export TERMINAL="alacritty"
export PAGER="less"

# Enhanced pager settings
export LESS="-R -F -X -i -M -W -z-4"
export LESSHISTFILE="$XDG_CACHE_HOME/less/history"

# Use bat for man pages if available
if command -v bat &> /dev/null; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# ===============================================================================
# SHELL CONFIGURATION
# ===============================================================================

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"

# History configuration
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export HISTSIZE=100000
export SAVEHIST=100000
export HISTTIMEFORMAT="[%F %T] "

# Create history directory if it doesn't exist
[[ ! -d "$(dirname "$HISTFILE")" ]] && mkdir -p "$(dirname "$HISTFILE")"

# ===============================================================================
# PATH CONFIGURATION
# ===============================================================================
# Organized by priority - most important paths first

# Initialize PATH with system defaults
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# User-specific paths (highest priority)
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Dotfiles scripts
export PATH="$SCRIPTS_DIR:$PATH"

# ===============================================================================
# DEVELOPMENT ENVIRONMENTS
# ===============================================================================

# === Node.js and JavaScript ===
export NODE_ENV="${NODE_ENV:-development}"
export NVM_DIR="$XDG_DATA_HOME/nvm"

# Bun configuration
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# PNPM configuration with XDG compliance
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export PATH="$PNPM_HOME:$PATH"
export PNPM_CACHE_FOLDER="$XDG_CACHE_HOME/pnpm"

# NPM configuration
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"
export PATH="$XDG_DATA_HOME/npm/bin:$PATH"

# Yarn configuration
export YARN_CACHE_FOLDER="$XDG_CACHE_HOME/yarn"

# === Python ===
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export PATH="$PYTHONUSERBASE/bin:$PATH"

# Poetry configuration
export POETRY_HOME="$XDG_DATA_HOME/poetry"
export POETRY_CACHE_DIR="$XDG_CACHE_HOME/poetry"
export POETRY_VIRTUALENVS_IN_PROJECT=true
export POETRY_VIRTUALENVS_PATH="$XDG_DATA_HOME/poetry/virtualenvs"
export PATH="$POETRY_HOME/bin:$PATH"

# Pip configuration
export PIP_CONFIG_FILE="$XDG_CONFIG_HOME/pip/pip.conf"
export PIP_LOG_FILE="$XDG_DATA_HOME/pip/log"

# === Rust ===
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export PATH="$CARGO_HOME/bin:$PATH"

# Rust performance optimizations
export CARGO_TARGET_DIR="$XDG_CACHE_HOME/cargo/target"
export RUSTC_WRAPPER="sccache"

# === Go ===
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export GOCACHE="$XDG_CACHE_HOME/go/build"
export PATH="$GOPATH/bin:$PATH"

# Go performance optimizations
export GOPROXY="https://proxy.golang.org,direct"
export GOSUMDB="sum.golang.org"

# === Java ===
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/default}"
export MAVEN_HOME="$XDG_DATA_HOME/maven"
export GRADLE_USER_HOME="$XDG_DATA_HOME/gradle"

# === Ruby ===
export GEM_HOME="$XDG_DATA_HOME/gem"
export GEM_SPEC_CACHE="$XDG_CACHE_HOME/gem"
export PATH="$GEM_HOME/bin:$PATH"

# === Other Languages ===
# Lua
export LUAROCKS_CONFIG="$XDG_CONFIG_HOME/luarocks/config-5.4.lua"

# R
export R_ENVIRON_USER="$XDG_CONFIG_HOME/R/Renviron"
export R_PROFILE_USER="$XDG_CONFIG_HOME/R/Rprofile"

# ===============================================================================
# CLOUD AND INFRASTRUCTURE TOOLS
# ===============================================================================

# Docker
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"

# Kubernetes
export KUBECONFIG="$XDG_CONFIG_HOME/kube/config"

# AWS
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"

# Terraform
export TF_CLI_CONFIG_FILE="$XDG_CONFIG_HOME/terraform/terraformrc"

# ===============================================================================
# MODERN CLI TOOLS CONFIGURATION
# ===============================================================================

# Bat (cat replacement)
export BAT_CONFIG_PATH="$XDG_CONFIG_HOME/bat/config"
export BAT_THEME="Catppuccin-mocha"

# FZF configuration
export FZF_DEFAULT_OPTS="
  --height 80%
  --layout reverse
  --border rounded
  --info inline
  --preview-window border-rounded
  --prompt '🔍 '
  --pointer '→'
  --marker '✓'
  --color 'fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8'
  --color 'fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8'
  --color 'info:#cba6ac,prompt:#cba6ac,pointer:#f5e0dc'
  --color 'marker:#f5e0dc,spinner:#f5e0dc,header:#f38ba8'
  --bind 'ctrl-y:execute-silent(echo {} | xclip -selection clipboard)'
  --bind 'ctrl-e:become(nvim {})'
  --bind 'ctrl-v:toggle-preview'"

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git --exclude node_modules"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git --exclude node_modules"

# Ripgrep configuration
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

# Zoxide configuration
export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"

# Atuin configuration
export ATUIN_CONFIG_DIR="$XDG_CONFIG_HOME/atuin"

# ===============================================================================
# VERSION CONTROL
# ===============================================================================

# Git configuration
export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"

# ===============================================================================
# TERMINAL AND DISPLAY
# ===============================================================================

# Terminal settings
export TERM="xterm-256color"
export COLORTERM="truecolor"

# Fix for some applications
export FORCE_COLOR=1
export CLICOLOR=1

# ===============================================================================
# PLATFORM-SPECIFIC CONFIGURATIONS
# ===============================================================================

# === WSL-specific settings ===
if [[ "$IS_WSL" -eq 1 ]]; then
  # Display and GUI settings
  export DISPLAY=":0"
  export LIBGL_ALWAYS_INDIRECT=1
  export BROWSER="wslview"

  # Windows integration
  if command -v cmd.exe &> /dev/null; then
    export WINHOME="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')"
  fi

  # WSL-specific clipboard
  export COPY_COMMAND="clip.exe"
else
  # Linux clipboard
  export COPY_COMMAND="xclip -selection clipboard"
fi

# === macOS-specific settings ===
if [[ "$IS_MACOS" -eq 1 ]]; then
  # Homebrew
  if [[ -d "/opt/homebrew" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
  else
    export HOMEBREW_PREFIX="/usr/local"
  fi
  export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"

  # macOS-specific settings
  export BROWSER="open"
  export COPY_COMMAND="pbcopy"
fi

# ===============================================================================
# PERFORMANCE AND SECURITY
# ===============================================================================

# Compilation flags
export ARCHFLAGS="-arch x86_64"
export MAKEFLAGS="-j$CPU_CORES"

# Security settings
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export PASSWORD_STORE_DIR="$XDG_DATA_HOME/pass"

# SSL/TLS settings
export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

# ===============================================================================
# APPLICATION-SPECIFIC CONFIGURATIONS
# ===============================================================================

# Wget
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"

# Curl
export CURL_HOME="$XDG_CONFIG_HOME/curl"

# Tmux
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"

# Less
export LESSKEY="$XDG_CONFIG_HOME/less/lesskey"
export LESSHISTFILE="$XDG_CACHE_HOME/less/history"

# ===============================================================================
# CLEANUP AND OPTIMIZATION
# ===============================================================================

# Remove duplicates from PATH
typeset -U PATH path

# Clean up temporary variables and functions
unset dir

# Validate critical paths
for critical_path in "$HOME/.local/bin" "$SCRIPTS_DIR"; do
  if [[ -d "$critical_path" ]] && [[ ":$PATH:" != *":$critical_path:"* ]]; then
    export PATH="$critical_path:$PATH"
  fi
done

# ===============================================================================
# DEBUGGING AND DEVELOPMENT
# ===============================================================================

# Enable debug mode if requested
if [[ "$DEBUG_DOTFILES" == "1" ]]; then
  echo "🐛 Debug mode enabled for dotfiles"
  echo "📁 DOTFILES_DIR: $DOTFILES_DIR"
  echo "🖥️  System: $(uname -s) (WSL: $IS_WSL, Container: $IS_CONTAINER)"
  echo "💻 Session: $SESSION_TYPE"
  echo "🏠 XDG_CONFIG_HOME: $XDG_CONFIG_HOME"
fi


