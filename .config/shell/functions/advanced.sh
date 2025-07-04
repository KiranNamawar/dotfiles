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
#!/bin/bash
# Advanced shell functions for power users

# Smart grep with syntax highlighting
smartgrep() {
  rg --color=always --line-number --no-heading --smart-case "${1:-}" . | fzf --ansi \
    --color "hl:-1:underline,hl+:-1:underline:reverse" \
    --delimiter : \
    --preview 'bat --color=always {1} --highlight-line {2}' \
    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
    --bind 'enter:become(nvim {1} +{2})'
}

# Quick project switcher
project_switch() {
  local projects_dir="$HOME/projects"
  local selected_project=$(fd --type d --max-depth 2 . "$projects_dir" | fzf --height 40% --layout reverse)
  if [[ -n "$selected_project" ]]; then
    cd "$selected_project"
    echo "📂 Switched to: $(basename "$selected_project")"
  fi
}

# Development environment setup
dev_setup() {
  local project_type="${1:-}"

  case "$project_type" in
    "node"|"js"|"ts")
      echo "🟢 Setting up Node.js development environment..."
      npm install
      if [[ -f "package.json" ]]; then
        echo "📦 Available scripts:"
        jq -r '.scripts | keys[]' package.json
      fi
      ;;
    "python"|"py")
      echo "🐍 Setting up Python development environment..."
      if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt
      fi
      if [[ -f "pyproject.toml" ]]; then
        pip install -e .
      fi
      ;;
    "rust"|"rs")
      echo "🦀 Setting up Rust development environment..."
      cargo build
      ;;
    "go")
      echo "🐹 Setting up Go development environment..."
      go mod tidy
      go build ./...
      ;;
    *)
      echo "❓ Unknown project type. Available: node, python, rust, go"
      return 1
      ;;
  esac
}

# Git workflow helper
git_workflow() {
  local action="${1:-}"

  case "$action" in
    "start")
      local branch_name="${2:-}"
      if [[ -z "$branch_name" ]]; then
        echo "❌ Please provide a branch name"
        return 1
      fi
      git checkout -b "$branch_name"
      echo "🌱 Created and switched to branch: $branch_name"
      ;;
    "finish")
      local current_branch=$(git branch --show-current)
      if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        echo "❌ Cannot finish on main/master branch"
        return 1
      fi
      git add .
      git commit -m "feat: $(echo $current_branch | sed 's/-/ /g')"
      git checkout main 2>/dev/null || git checkout master
      echo "✅ Finished work on: $current_branch"
      ;;
    "clean")
      git branch --merged | grep -v "\*\|main\|master" | xargs -n 1 git branch -d
      echo "🧹 Cleaned up merged branches"
      ;;
    *)
      echo "Available actions: start <branch-name>, finish, clean"
      ;;
  esac
}

# System monitoring dashboard
system_monitor() {
  echo "🖥️  System Monitor Dashboard"
  echo "=========================="
  echo "📊 CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
  echo "💾 Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
  echo "💿 Disk: $(df -h / | awk 'NR==2{print $5}')"
  echo "🌡️  Temperature: $(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' || echo 'N/A')"
  echo "🔋 Battery: $(acpi 2>/dev/null | grep -o '[0-9]*%' || echo 'N/A')"
  echo "📡 Network: $(ip route get 8.8.8.8 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2 || echo 'Offline')"
}

# Code quality checker
code_quality() {
  local project_dir="${1:-.}"
  echo "🔍 Running code quality checks..."

  # Check for common files
  if [[ -f "$project_dir/package.json" ]]; then
    echo "📦 Node.js project detected"
    if command -v eslint &> /dev/null; then
      echo "🔧 Running ESLint..."
      eslint "$project_dir"
    fi
    if command -v prettier &> /dev/null; then
      echo "✨ Running Prettier..."
      prettier --check "$project_dir"
    fi
  fi

  if [[ -f "$project_dir/pyproject.toml" ]] || [[ -f "$project_dir/setup.py" ]]; then
    echo "🐍 Python project detected"
    if command -v black &> /dev/null; then
      echo "⚫ Running Black..."
      black --check "$project_dir"
    fi
    if command -v flake8 &> /dev/null; then
      echo "🔍 Running Flake8..."
      flake8 "$project_dir"
    fi
  fi

  if [[ -f "$project_dir/Cargo.toml" ]]; then
    echo "🦀 Rust project detected"
    echo "🔧 Running cargo fmt..."
    cargo fmt --check
    echo "📎 Running cargo clippy..."
    cargo clippy
  fi
}

# Smart file search and edit
smart_edit() {
  local search_term="${1:-}"
  if [[ -z "$search_term" ]]; then
    # Use fzf to select file
    local file=$(fd --type f | fzf --preview 'bat --color=always {}' --height 80%)
    if [[ -n "$file" ]]; then
      $EDITOR "$file"
    fi
  else
    # Search for files containing the term
    local files=$(rg -l "$search_term" | fzf --preview "rg --color=always '$search_term' {}")
    if [[ -n "$files" ]]; then
      $EDITOR "$files"
    fi
  fi
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
