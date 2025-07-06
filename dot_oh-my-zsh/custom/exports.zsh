# =============================================================================
# SYSTEM ENVIRONMENT
# =============================================================================

# Default applications
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='bat'
export BROWSER='firefox'


# =============================================================================
# XDG BASE DIRECTORY SPECIFICATION
# =============================================================================

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"


# =============================================================================
# PATH CONFIGURATION
# =============================================================================

# Local binaries
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# System paths
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/bin:$PATH"
export PATH="/bin:$PATH"


# =============================================================================
# TOOL SPECIFIC CONFIGURATIONS
# =============================================================================

# FZF Configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="
    --height 40%
    --layout=reverse
    --border
    --inline-info
    --preview 'bat --style=numbers --color=always --line-range :500 {}'
    --preview-window right:50%:wrap
    --bind 'ctrl-/:change-preview-window(down|hidden|)'
    --bind 'ctrl-y:execute-silent(echo {} | clip.exe)'
    --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796
    --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6
    --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796
"

# BAT Configuration
export BAT_THEME="DarkNeon"
export BAT_CONFIG_PATH="$XDG_CONFIG_HOME/bat/config"
export BAT_STYLE="numbers,changes,header"

# Ripgrep Configuration
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/ripgreprc"

# ATUIN Configuration
export ATUIN_NOBIND="true"

# ZOXIDE Configuration
export _ZO_ECHO=1
export _ZO_RESOLVE_SYMLINKS=1
