# ~/dotfiles/zsh/functions.zsh

# --- Create and move into a directory ---
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# --- Extract various archive formats ---
extract() {
  if [[ -f "$1" ]]; then
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
      *)           echo "❌ Unknown archive format: $1" ;;
    esac
  else
    echo "❌ File not found: $1"
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

# --- Reload zsh config ---
reload_zsh() {
  source ~/.zshrc && echo "✅ ZSH reloaded!"
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

