# ~/dotfiles/zsh/functions.zsh
# Smart Functions for Ultimate Terminal Experience
# Last updated: July 3, 2025

# === Welcome Message Function ===
# This function displays the welcome message when opening a new shell
display_welcome_message() {
  echo -e "\n$(date '+%A, %B %d, %Y %H:%M')"
  echo -e "\n💡 $(shuf -n 1 $DOTFILES_DIR/resources/quotes.txt 2>/dev/null || echo 'Welcome to your ultimate terminal!')"
  fastfetch
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
      *.tar.bz2)   pv "$1" | tar xjf -     ;;
      *.tar.gz)    pv "$1" | tar xzf -     ;;
      *.tar.xz)    pv "$1" | tar xJf -     ;;
      *.lzma)      unlzma "$1"      ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar x "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       pv "$1" | tar xf -      ;;
      *.tbz2)      pv "$1" | tar xjf -     ;;
      *.tgz)       pv "$1" | tar xzf -     ;;
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

# Initialize a new project with smart templates
project_init() {
  if [[ -z "$1" ]]; then
    echo "❌ Please provide a project name"
    return 1
  fi
  
  local project_name="$1"
  local project_type="${2:-general}"
  
  echo "🚀 Creating $project_type project: $project_name"
  mkcd "$project_name"
  
  case "$project_type" in
    node|nodejs)
      echo "📦 Setting up Node.js project..."
      npm init -y
      echo "node_modules/" > .gitignore
      mkdir -p src test
      ;;
    python)
      echo "🐍 Setting up Python project..."
      python -m venv .venv
      echo ".venv/" > .gitignore
      echo "__pycache__/" >> .gitignore
      mkdir -p src tests
      ;;
    go|golang)
      echo "🚀 Setting up Go project..."
      go mod init "$project_name"
      mkdir -p cmd pkg internal
      ;;
    *)
      echo "📝 Setting up general project structure..."
      mkdir -p src docs assets
      ;;
  esac
  
  # Initialize git
  git init
  echo "✅ Project initialized successfully!"
  
  # Auto-open in editor if wanted
  if [[ "$3" == "--open" ]]; then
    $EDITOR .
  fi
}

# Git-aware project status dashboard
project_status() {
  local dir="${1:-.}"
  echo "📊 Project Status for $(basename $(realpath $dir))"
  echo "----------------------------------------"
  
  # Git status if available
  if [[ -d "$dir/.git" ]]; then
    echo "🔄 Git Status:"
    git -C "$dir" status -s
    echo ""
    echo "📈 Recent Activity:"
    git -C "$dir" log --oneline -5
    echo ""
  fi
  
  # Files overview
  echo "📁 File Structure:"
  ls -la "$dir" | grep -v "^total"
  
  # Project-specific information
  if [[ -f "$dir/package.json" ]]; then
    echo ""
    echo "📦 Node.js Project"
    echo "Dependencies: $(jq '.dependencies | length' "$dir/package.json") regular, $(jq '.devDependencies | length' "$dir/package.json") dev"
  elif [[ -f "$dir/requirements.txt" ]]; then
    echo ""
    echo "🐍 Python Project"
    echo "Dependencies: $(wc -l < "$dir/requirements.txt")"
  fi
}

# --- Bookmark current directory ---
bookmark() {
  echo "cd $(pwd)" >> ~/.marks
  echo "🔖 Bookmarked: $(pwd)"
}

# --- Jump to a bookmark using fzf ---
marks() {
  cat ~/.marks 2>/dev/null | fzf | source /dev/stdin
}

# --- Backup a file or folder with timestamp ---
backup() {
  cp -r "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"
}

# --- Clean all node_modules recursively ---
clean_node_modules() {
  find . -type d -name 'node_modules' -prune -exec rm -rf '{}' +
  echo "🧹 Removed all node_modules."
}

# --- Count total lines of code (ignores dist and node_modules) ---
count_lines() {
  find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" \
    | xargs wc -l
}

# --- Get your local IP ---
myip() {
  ip addr show | awk '/inet / && !/127.0.0.1/ {print $2}' | cut -d/ -f1
}

# --- Show top 10 largest directories/files ---
top10() {
  du -ah . | sort -rh | head -n 10
}

# --- Confirm before deleting ---
confirm_rm() {
  echo -n "❓ Delete $1? [y/N]: "
  read ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    rm -rf "$1"
    echo "🗑️ Removed $1"
  else
    echo "🚫 Cancelled."
  fi
}

# --- Open LazyGit in current repo ---
lgit() {
  git rev-parse --show-toplevel &>/dev/null && lazygit || echo "❌ Not a Git repo"
}

# --- Fuzzy open file with preview ---
fuzzyedit() {
  local file
  file=$(fzf --preview 'bat --style=numbers --color=always {} | head -100') && nvim "$file"
}

# --- Search command history with fzf ---
histfzf() {
  local selected_cmd

  selected_cmd=$(atuin search --format=tsv --limit 10000 \
    | awk -F'\t' '{print $2 "\t" $1 "\t" $3}' \
    | fzf --reverse --tiebreak=index \
          --prompt="History > " \
          --preview='echo {} | cut -f1 | bat --style=plain --color=always' \
          --preview-window=down:3:wrap \
          --header="⏱ Command | 📅 Timestamp | 📁 Directory" \
          --bind "enter:accept"
  )

  if [ -n "$selected_cmd" ]; then
    BUFFER=$(echo "$selected_cmd" | cut -f1)
    zle accept-line
  fi
}
zle -N histfzf
bindkey '^r' histfzf  # Ctrl+R binds to histfzf

