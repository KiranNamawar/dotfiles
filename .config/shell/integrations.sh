#!/usr/bin/env bash
# ~/.config/shell/integrations.sh
# Cross-tool integration for ultimate terminal experience

# Smart tool detection and initialization
if command -v fzf &> /dev/null; then
  # Enhanced FZF integration with ripgrep
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  
  # FZF functions for enhanced workflow
  fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
    if [ "x$pid" != "x" ]; then
      echo $pid | xargs kill -${1:-9}
    fi
  }
fi

# Smart git integration
if command -v git &> /dev/null; then
  # Auto-fetch in git repos
  auto_git_fetch() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
      git fetch --all --quiet &
    fi
  }
  
  # Add to prompt precmd if available
  if [[ -n $ZSH_VERSION ]]; then
    autoload -U add-zsh-hook
    add-zsh-hook precmd auto_git_fetch
  fi
fi

# Tmux integration
if command -v tmux &> /dev/null; then
  # Auto-attach to existing session or create new one
  ta() {
    local session_name="${1:-main}"
    if tmux has-session -t "$session_name" 2>/dev/null; then
      tmux attach-session -t "$session_name"
    else
      tmux new-session -s "$session_name"
    fi
  }
fi
#!/bin/bash
# Shell integrations for modern developer tools

# Zoxide initialization (better cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi

# Atuin initialization (better history)
if command -v atuin &> /dev/null; then
  eval "$(atuin init bash)"
fi

# FZF key bindings and completion
if command -v fzf &> /dev/null; then
  # Set up fzf key bindings and fuzzy completion
  eval "$(fzf --bash)"

  # Custom FZF functions
  export FZF_DEFAULT_OPTS="
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6ac,pointer:#f5e0dc
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6ac,hl+:#f38ba8
    --height=40% --layout=reverse --border --info=inline"

  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
fi

# Direnv hook for automatic environment loading
if command -v direnv &> /dev/null; then
  eval "$(direnv hook bash)"
fi

# Github CLI completion
if command -v gh &> /dev/null; then
  eval "$(gh completion -s bash)"
fi

# Docker completion
if command -v docker &> /dev/null; then
  source /usr/share/bash-completion/completions/docker 2>/dev/null
fi
# Docker integration
if command -v docker &> /dev/null; then
  # Quick container management
  alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
  alias dlogs="docker logs -f"
  alias dexec="docker exec -it"
fi

# WSL-specific integrations
if grep -q Microsoft /proc/version 2>/dev/null; then
  # Enhanced clipboard integration
  alias pbcopy='clip.exe'
  alias pbpaste='powershell.exe -command "Get-Clipboard" | tr -d "\r"'
  
  # Windows path conversion
  winpath() {
    wslpath -w "$1" | clip.exe
    echo "Windows path copied to clipboard: $(wslpath -w "$1")"
  }
fi
