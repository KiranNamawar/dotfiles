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
