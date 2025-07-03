# ~/dotfiles/zsh/exports.zsh

# === Editor and Pager ===
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# === Locale ===
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# === XDG Standard Directories ===
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# === Node.js & Bun ===
export NODE_ENV="development"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# === Go (optional, if installed) ===
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# === PNPM ===
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# === Bun Cache Optimization ===
export BUN_DISABLE_GC=true

# === Terminal ===
export TERM="xterm-256color"
export TERMINAL="alacritty"

# === Bat Config ===
export BAT_THEME="Catppuccin-mocha"

# === FZF ===
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
export FZF_CTRL_T_COMMAND="fd --type f"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always {} | head -100'"

# === Path Priority Order ===
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

export FZF_DEFAULT_COMMAND='fd --type f'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# === Tmux Powerline ===
export TMUX_POWERLINE_DIR="$HOME/.tmux-powerline"
export TMUX_POWERLINE_CONFIG_FILE="$TMUX_POWERLINE_DIR/config/default.sh"
export TMUX_POWERLINE_SEGMENTS_DIR="$TMUX_POWERLINE_DIR/segments"

