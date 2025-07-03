#!/usr/bin/env bash
# ~/.config/shell/functions/advanced.sh
# Advanced shell functions for productivity and workflow enhancement
# Last updated: July 3, 2025

# === Welcome Message Function ===
display_welcome_message() {
  echo -e "\n$(date '+%A, %B %d, %Y %H:%M')"
  echo -e "\n💡 $(shuf -n 1 ~/dotfiles/resources/quotes.txt 2>/dev/null || echo 'Welcome to your ultimate terminal!')"
  if command -v fastfetch &> /dev/null; then
    fastfetch
  elif command -v neofetch &> /dev/null; then
    neofetch
  fi
}

# === File System Operations ===

# Create and move into a directory
mkcd() {
  mkdir -p "$1" && cd "$1" && echo "📁 Created and moved to $PWD"
}

# Extract archives with progress and intelligent handling
extract() {
  if [[ -f "$1" ]]; then
    echo "🔄 Extracting $(basename $1)..."
    case "$1" in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.tar.xz)    tar xJf "$1"     ;;
      *.lzma)      unlzma "$1"      ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar x "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "❌ Unknown archive format: $1" && return 1 ;;
    esac
    echo "✅ Extraction complete!"
  else
    echo "❌ File not found: $1"
    return 1
  fi
}

# Smart file finder with preview
ff() {
  local result=$(fzf --preview 'bat --color=always {}' --height 80% --layout reverse)
  if [[ -n "$result" ]]; then
    $EDITOR "$result"
  fi
}

# === Project Management ===
project_init() {
  local name="$1"
  local type="${2:-general}"
  
  if [[ -z "$name" ]]; then
    echo "Usage: project_init <name> [type]"
    echo "Types: node, python, rust, go, general"
    return 1
  fi
  
  mkdir -p "$name" && cd "$name"
  
  case "$type" in
    node)
      npm init -y
      echo "node_modules/\n.env\n*.log" > .gitignore
      mkdir -p src test
      ;;
    python)
      python -m venv .venv
      echo ".venv/\n__pycache__/\n*.pyc\n.env" > .gitignore
      echo "# $name\n" > README.md
      ;;
    rust)
      cargo init
      ;;
    go)
      go mod init "$name"
      echo "# $name\n" > README.md
      ;;
    *)
      echo "# $name\n" > README.md
      ;;
  esac
  
  git init
  git add .
  git commit -m "Initial commit"
  echo "✅ Project '$name' ($type) initialized!"
}

# Smart directory navigation with context
smart_cd() {
  if [[ -z "$1" ]]; then
    cd "$HOME"
    return
  fi
  
  # Try exact match first
  if [[ -d "$1" ]]; then
    cd "$1"
    return
  fi
  
  # Try fuzzy finding in common directories
  local result
  result=$(find ~/projects ~/work ~/dotfiles -maxdepth 2 -type d -name "*$1*" 2>/dev/null | head -1)
  
  if [[ -n "$result" ]]; then
    cd "$result"
    echo "📁 Found: $result"
  else
    echo "❌ Directory not found: $1"
    return 1
  fi
}

# Enhanced file search with preview
search() {
  local query="$1"
  if [[ -z "$query" ]]; then
    echo "Usage: search <pattern>"
    return 1
  fi
  
  rg --color=always --line-number --no-heading --smart-case "$query" |
    fzf --ansi \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --delimiter : \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind 'enter:become(nvim {1} +{2})'
}

# Git workflow helpers
git_clean_branches() {
  git branch --merged | grep -v "\*\|main\|master\|develop" | xargs -n 1 git branch -d
  echo "🧹 Cleaned merged branches"
}

git_squash_commits() {
  local count="${1:-2}"
  git reset --soft HEAD~"$count"
  git commit --edit -m"$(git log --format=%B --reverse HEAD..HEAD@{1})"
  echo "📦 Squashed last $count commits"
}

# System monitoring shortcuts
top_processes() {
  ps aux --sort=-%cpu | head -10
}

disk_usage() {
  df -h | grep -E '^/dev/' | sort -k5 -nr
}

# Development helpers
serve() {
  local port="${1:-8000}"
  if command -v python3 &> /dev/null; then
    python3 -m http.server "$port"
  elif command -v python &> /dev/null; then
    python -m SimpleHTTPServer "$port"
  else
    echo "❌ Python not found"
    return 1
  fi
}

# Quick notes system
note() {
  local note_file="$HOME/notes/$(date +%Y-%m-%d).md"
  mkdir -p "$HOME/notes"
  
  if [[ $# -eq 0 ]]; then
    nvim "$note_file"
  else
    echo "$(date '+%H:%M') - $*" >> "$note_file"
    echo "📝 Note added to $(basename "$note_file")"
  fi
}
