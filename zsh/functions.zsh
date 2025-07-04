#!/usr/bin/env zsh
# ~/dotfiles/zsh/functions_minimal.zsh
# Essential functions only - cleaned up to avoid errors

# ===============================================================================
# SYSTEM INFORMATION AND WELCOME
# ===============================================================================

# Enhanced welcome message with system information
display_welcome_message() {
  local current_time=$(date '+%A, %B %d, %Y %H:%M')
  local uptime_info=$(uptime | awk -F'( |,|:)+' '{print $6,$7",",$8,"hours,",$9,"minutes"}')

  echo ""
  echo "📅 $current_time"
  echo "⏰ System uptime: $uptime_info"

  # Display random quote if available
  if [[ -f "$DOTFILES_DIR/resources/quotes.txt" ]]; then
    echo ""
    echo "💡 $(shuf -n 1 "$DOTFILES_DIR/resources/quotes.txt")"
  fi

  # System info with fastfetch if available
  if command -v fastfetch &> /dev/null; then
    echo ""
    fastfetch
  fi

  # Git repository info if in a repo
  if git rev-parse --git-dir &> /dev/null; then
    local branch=$(git branch --show-current)
    local changes=$(git status --porcelain | wc -l)
    echo ""
    echo "🌿 Git: $branch ($changes changes)"
  fi
}

# System monitoring dashboard
sysmon() {
  echo "🖥️  System Monitor Dashboard"
  echo "=========================="
  echo "📊 CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
  echo "💾 Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
  echo "💿 Disk: $(df -h / | awk 'NR==2{print $5}')"
  echo "👤 User: $USER"
  echo "🐚 Shell: $SHELL"
  echo "📂 PWD: $PWD"
}

# ===============================================================================
# FILE SYSTEM OPERATIONS
# ===============================================================================

# Create directory and navigate to it
mkcd() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: mkcd <directory_name>"
    return 1
  fi

  mkdir -p "$1" && cd "$1"
  echo "📁 Created and moved to: $(pwd)"
}

# Backup file or directory with timestamp
backup() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: backup <file_or_directory>"
    return 1
  fi

  if [[ ! -e "$1" ]]; then
    echo "❌ File or directory not found: $1"
    return 1
  fi

  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_name="${1}.bak.${timestamp}"

  cp -r "$1" "$backup_name"
  echo "✅ Backup created: $backup_name"
}

# Safe file removal with confirmation
safe_rm() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: safe_rm <file_or_directory>"
    return 1
  fi

  echo -n "❓ Delete '$1'? [y/N]: "
  read -r response
  case "$response" in
    [yY][eE][sS]|[yY])
      rm -rf "$1"
      echo "🗑️  Deleted: $1"
      ;;
    *)
      echo "🚫 Cancelled deletion"
      ;;
  esac
}

# ===============================================================================
# GIT UTILITIES
# ===============================================================================

# Simple git status function
gitstatus() {
  if ! git rev-parse --git-dir &> /dev/null; then
    echo "❌ Not in a git repository"
    return 1
  fi

  local branch=$(git branch --show-current)
  local change_count=$(git status --porcelain | wc -l)

  echo "🌿 Branch: $branch"
  echo "📝 Changes: $change_count"
  echo ""

  git status --short
}

# Git commit with conventional commit format
gcomit() {
  if [[ $# -lt 2 ]]; then
    echo "❌ Usage: gcomit <type> <message> [scope]"
    echo "Types: feat, fix, docs, style, refactor, test, chore"
    return 1
  fi

  local type="$1"
  local message="$2"
  local scope="$3"

  local commit_message="$type"
  if [[ -n "$scope" ]]; then
    commit_message="$type($scope)"
  fi
  commit_message="$commit_message: $message"

  git commit -m "$commit_message"
}

# Simple git add function
gitadd() {
  if [[ -z "$1" ]]; then
    git add -A
    echo "✅ Added all files"
  else
    git add "$@"
    echo "✅ Added: $*"
  fi
}

# ===============================================================================
# NETWORK AND SYSTEM UTILITIES
# ===============================================================================

# Network information
netinfo() {
  echo "🌐 Network Information"
  echo "===================="
  echo "🏠 Local IP: $(ip route get 8.8.8.8 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2)"
  echo "🌍 Public IP: $(curl -s ifconfig.me)"
  echo ""
  echo "🚪 Open ports:"
  ss -tuln | grep LISTEN
}

# Check if a port is open
check_port() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: check_port <port>"
    return 1
  fi

  local port="$1"
  if ss -tuln | grep -q ":$port "; then
    echo "✅ Port $port is open"
    ss -tuln | grep ":$port "
  else
    echo "❌ Port $port is closed or not listening"
  fi
}

# ===============================================================================
# CLEANUP AND MAINTENANCE
# ===============================================================================

# Clean node_modules recursively
clean_node() {
  echo "🧹 Cleaning node_modules directories..."
  find . -name "node_modules" -type d -prune -exec rm -rf '{}' +
  echo "✅ All node_modules directories removed"
}

# ===============================================================================
# UTILITY FUNCTIONS
# ===============================================================================

# Create and serve a simple HTTP server
serve() {
  local port="${1:-8000}"
  local dir="${2:-.}"

  echo "🌐 Starting HTTP server on port $port serving $dir"
  echo "📱 Access at: http://localhost:$port"

  if command -v python3 &> /dev/null; then
    python3 -m http.server "$port" --directory "$dir"
  elif command -v python &> /dev/null; then
    cd "$dir" && python -m SimpleHTTPServer "$port"
  else
    echo "❌ Python not found"
    return 1
  fi
}

# Generate random password
genpass() {
  local length="${1:-16}"
  if command -v openssl &> /dev/null; then
    openssl rand -base64 "$length" | cut -c1-"$length"
  else
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c "$length" && echo
  fi
}

# Weather function
weather() {
  local location="${1:-}"
  if [[ -n "$location" ]]; then
    curl "wttr.in/$location"
  else
    curl "wttr.in"
  fi
}

# Note taking function
note() {
  local notes_dir="$HOME/notes"
  local date_format=$(date +%Y-%m-%d)

  [[ ! -d "$notes_dir" ]] && mkdir -p "$notes_dir"

  if [[ -z "$1" ]]; then
    # Open today's note
    $EDITOR "$notes_dir/$date_format.md"
  else
    # Create/open specific note
    $EDITOR "$notes_dir/$1.md"
  fi
}

# ===============================================================================
# FUZZY FINDER INTEGRATIONS
# ===============================================================================

# Fuzzy file finder and editor
ff() {
  # Only work in interactive shells
  [[ ! -o interactive ]] && { echo "❌ This function requires an interactive shell"; return 1; }
  
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed"
    return 1
  fi

  local file
  if command -v fd &> /dev/null; then
    file=$(fd --type f --hidden --follow --exclude .git | fzf --preview 'bat --color=always {} 2>/dev/null || cat {}' --height 80% --layout reverse)
  else
    file=$(find . -type f | fzf --preview 'bat --color=always {} 2>/dev/null || cat {}' --height 80% --layout reverse)
  fi

  if [[ -n "$file" ]]; then
    ${EDITOR:-vim} "$file"
  fi
}

# Fuzzy directory navigation
fcd() {
  # Only work in interactive shells
  [[ ! -o interactive ]] && { echo "❌ This function requires an interactive shell"; return 1; }
  
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed"
    return 1
  fi

  local dir
  if command -v fd &> /dev/null; then
    dir=$(fd --type d --hidden --follow --exclude .git | fzf --height 40% --layout reverse)
  else
    dir=$(find . -type d | fzf --height 40% --layout reverse)
  fi

  if [[ -n "$dir" ]]; then
    cd "$dir"
  fi
}

# Fuzzy process killer
fkill() {
  # Only work in interactive shells
  [[ ! -o interactive ]] && { echo "❌ This function requires an interactive shell"; return 1; }
  
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed"
    return 1
  fi

  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

  if [[ -n "$pid" ]]; then
    echo "Killing process(es): $pid"
    kill -TERM $pid
  fi
}

# Fuzzy git branch checkout
fgb() {
  # Only work in interactive shells
  [[ ! -o interactive ]] && { echo "❌ This function requires an interactive shell"; return 1; }
  
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed"
    return 1
  fi

  if ! git rev-parse --git-dir &> /dev/null; then
    echo "❌ Not in a git repository"
    return 1
  fi

  local branch
  branch=$(git branch --all | grep -v HEAD | sed 's/^[ *]*//' | sed 's/remotes\///' | sort -u | fzf)

  if [[ -n "$branch" ]]; then
    git checkout "$branch"
  fi
}

# Interactive git add
gadd() {
  # Only work in interactive shells
  [[ ! -o interactive ]] && { echo "❌ This function requires an interactive shell"; return 1; }
  
  if ! command -v fzf &> /dev/null; then
    git add -p
    return
  fi

  local files
  files=$(git status --porcelain | fzf -m --ansi --preview 'git diff --color=always {2}' | awk '{print $2}')

  if [[ -n "$files" ]]; then
    echo "$files" | xargs git add
    echo "✅ Added files: $files"
  fi
}

# Enhanced history search with fzf
histfzf() {
  # Only work in interactive shells
  [[ ! -o interactive ]] && { echo "❌ This function requires an interactive shell"; return 1; }
  
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed"
    return 1
  fi

  local selected_cmd

  if command -v atuin &> /dev/null; then
    selected_cmd=$(atuin search --format=tsv --limit 10000 \
      | awk -F'\t' '{print $2 "\t" $1 "\t" $3}' \
      | fzf --reverse --tiebreak=index \
            --prompt="History > " \
            --preview='echo {} | cut -f1 | bat --style=plain --color=always --language=bash 2>/dev/null || echo {}' \
            --preview-window=down:3:wrap \
            --header="⏱ Command | 📅 Timestamp | 📁 Directory" \
            --bind "enter:accept"
    )

    if [[ -n "$selected_cmd" ]]; then
      local command=$(echo "$selected_cmd" | cut -f1)
      print -z "$command"  # Put command in buffer for editing
    fi
  else
    selected_cmd=$(history | sort -nr | fzf --no-sort --query="$1")
    if [[ -n "$selected_cmd" ]]; then
      local command=$(echo "$selected_cmd" | sed 's/^[ ]*[0-9]*[ ]*//')
      print -z "$command"  # Put command in buffer for editing
    fi
  fi
}

# Quick project switcher
project_switch() {
  # Only work in interactive shells
  [[ ! -o interactive ]] && { echo "❌ This function requires an interactive shell"; return 1; }
  
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed"
    return 1
  fi

  local projects_dirs=("$HOME/projects" "$HOME/work" "$HOME/repositories" "$HOME/dev")
  local all_projects=()

  for dir in "${projects_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      while IFS= read -r -d '' project; do
        all_projects+=("$project")
      done < <(find "$dir" -maxdepth 2 -type d -name ".git" -exec dirname {} \; -print0 2>/dev/null)
    fi
  done

  if [[ ${#all_projects[@]} -eq 0 ]]; then
    echo "❌ No projects found in common directories"
    return 1
  fi

  local selected_project=$(printf '%s\n' "${all_projects[@]}" | fzf --height 40% --layout reverse --prompt "Project > ")

  if [[ -n "$selected_project" ]]; then
    cd "$selected_project"
    echo "📂 Switched to: $(basename "$selected_project")"
  fi
}

# Simple file finder (non-interactive fallback)
find_files() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: find_files <pattern>"
    return 1
  fi
  
  if command -v fd &> /dev/null; then
    fd "$1"
  else
    find . -name "*$1*" -type f
  fi
}

# Simple directory finder (non-interactive fallback)
find_dirs() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: find_dirs <pattern>"
    return 1
  fi
  
  if command -v fd &> /dev/null; then
    fd "$1" --type d
  else
    find . -name "*$1*" -type d
  fi
}

# ===============================================================================
# LOAD USER CUSTOM FUNCTIONS
# ===============================================================================

# Load user-specific functions (not tracked in git)
[[ -f "$HOME/.functions.local" ]] && source "$HOME/.functions.local"
