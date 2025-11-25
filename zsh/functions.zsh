
# --- Load OCI Functions
if [ -f ~/.dotfiles/zsh/oci_functions.zsh ]; then
    source ~/.dotfiles/zsh/oci_functions.zsh
fi

# --- Load Other Functions
if [ -f ~/.dotfiles/zsh/other_functions.zsh ]; then
    source ~/.dotfiles/zsh/other_functions.zsh
fi


# ------------------------------------------
# JQE (JSON Query Explorer)
# Usage: jqe file.json OR echo '{"a":1}' | jqe
# ------------------------------------------
jqe() {
  local INPUT_FILE=$(mktemp /tmp/jqe_XXXXXX.json)
  
  # 1. Input Handling: Pipe or File argument?
  if [ -f "$1" ]; then
    cat "$1" > "$INPUT_FILE"
  else
    # Read from Stdin (Piped input)
    # If stdin is empty, show usage
    if [ -t 0 ]; then
      echo "Usage: jqe <file> OR command | jqe"
      rm "$INPUT_FILE"
      return 1
    fi
    cat > "$INPUT_FILE"
  fi

  # 2. Check validity
  if ! jq empty "$INPUT_FILE" 2>/dev/null; then
    echo "❌ Error: Invalid JSON input."
    rm "$INPUT_FILE"
    return 1
  fi

  # 3. The Explorer Logic
  # We use JQ to generate a list of ALL paths (e.g. .user.name, .list[0].id)
  # Then feed that list to FZF
  local SELECTED_PATH=$(jq -r '
    paths 
    | map(if type=="number" then "["+tostring+"]" else "[\""+tostring+"\"]" end) 
    | join("") 
    | "." + .' "$INPUT_FILE" \
    | fzf --height 60% --layout=reverse --border \
          --header="JSON Explorer (Type to filter paths)" \
          --preview "jq -C {1} $INPUT_FILE" \
          --preview-window='right:60%:wrap')

  # 4. Cleanup & Output
  if [ -n "$SELECTED_PATH" ]; then
    # Extract the value at the selected path
    local VALUE=$(jq -r "$SELECTED_PATH" "$INPUT_FILE")
    
    # Copy to clipboard
    if command -v wl-copy &> /dev/null; then echo -n "$VALUE" | wl-copy
    elif command -v xclip &> /dev/null; then echo -n "$VALUE" | xclip -selection clipboard; fi
    
    echo "✅ Copied: $SELECTED_PATH"
    # Print value to stdout so it can be chained (e.g. jqe file | less)
    echo "$VALUE"
  fi

  rm "$INPUT_FILE"
}


# ------------------------------------------
# FUZZY CD (lsd edition)
# ------------------------------------------
fcd() {
    # 1. Source: Use 'fd' (fast) or fallback to 'find'
    local source_cmd
    if command -v fd &> /dev/null; then
        source_cmd="fd --type d --hidden --exclude .git"
    else
        source_cmd="find . -maxdepth 5 -type d -not -path '*/.*'"
    fi

    # 2. Preview: Use 'lsd' for the tree view
    local preview_cmd
    if command -v lsd &> /dev/null; then
        # --tree: Recursive tree view
        # --depth 2: Only show 2 levels deep (keeps preview clean)
        # --color always: Keep colors inside fzf
        preview_cmd="lsd --tree --depth 2 --color always --icon always {}"
    elif command -v tree &> /dev/null; then
        preview_cmd="tree -C -L 2 {}"
    else
        preview_cmd="ls -A --color=always {}"
    fi

    # 3. Run FZF
    local dir=$(eval "$source_cmd" | fzf \
        --height=50% \
        --layout=reverse \
        --border \
        --prompt="📂 Go To > " \
        --header="CTRL-E: Edit in Nvim | ENTER: Cd" \
        --preview="$preview_cmd" \
        --preview-window="right:50%:wrap" \
        --bind "ctrl-e:execute(nvim {} > /dev/tty)" \
    )

    # 4. Execute
    if [[ -n "$dir" ]]; then
        cd "$dir"
    fi
}


# ------------------------------------------
# PROJECT SESSIONIZER (proj)
# ------------------------------------------
proj() {
    local PROJECT_ROOT="$HOME/Projects"

    # 1. SEARCH LOGIC (The Fix)
    # We cd into root first so 'fd' returns relative paths (e.g., "test" instead of "/home/...")
    # --max-depth 2: Prevents digging into 'src', 'public', etc.
    #    Assumes structure is either Projects/Repo or Projects/Category/Repo
    local selected=$(
        cd "$PROJECT_ROOT" && \
        fd --type d \
           --min-depth 1 \
           --max-depth 2 \
           --hidden \
           --exclude .git \
           --exclude node_modules \
           . \
        | fzf \
            --height=40% \
            --layout=reverse \
            --border \
            --prompt="🚀 Launch Project > " \
            --header="CTRL-R: Rescan" \
            --preview="lsd --tree --depth 2 --color always --icon always --ignore-glob node_modules --ignore-glob .git $PROJECT_ROOT/{}" \
            --preview-window="right:50%:wrap"
    )

    # Exit if cancelled
    if [[ -z "$selected" ]]; then return; fi

    # 2. PATH RECONSTRUCTION
    # Since we selected a relative path, we add the root back
    local full_path="$PROJECT_ROOT/$selected"
    
    # 3. SESSION NAMING
    # "learn/react" -> "learn_react"
    local session_name=$(echo "$selected" | tr . _ | tr / _)

    # 4. TMUX LOGIC
    if ! tmux has-session -t="$session_name" 2> /dev/null; then
        tmux new-session -ds "$session_name" -c "$full_path"
    fi

    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    fi
}

# Bind to CTRL+P
# Widget for fop
_proj_widget() {
    proj
    zle reset-prompt
}
zle -N _proj_widget
bindkey '^p' _proj_widget


# ------------------------------------------
# FUZZY OPEN (File or Dir -> Nvim)
# ------------------------------------------
fop() {
    # 1. SETUP COMMANDS
    # We prefer 'fd' because it's fast. Fallback to 'find'.
    local find_cmd
    if command -v fd &> /dev/null; then
        # Look for both files and dirs, ignore git/node_modules
        find_cmd="fd --hidden --follow --exclude .git --exclude node_modules"
    else
        find_cmd="find . -maxdepth 5 -not -path '*/.*' -not -path '*/node_modules*'"
    fi

    # 2. HYBRID PREVIEW LOGIC
    # - If it's a directory: use lsd tree
    # - If it's a file: use bat (with syntax highlighting) or cat
    local preview_cmd="if [ -d {} ]; then 
        lsd --tree --depth 1 --color always --icon always {}; 
    else 
        bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {}; 
    fi"

    # 3. RUN FZF
    # We add bindings to filter on the fly:
    # CTRL-D: Show only Directories
    # CTRL-F: Show only Files
    local selected=$(eval "$find_cmd" | fzf \
        --layout=reverse \
        --border \
        --height=80% \
        --prompt="🔮 Open > " \
        --header="CTRL-D: Dirs only | CTRL-F: Files only" \
        --preview="$preview_cmd" \
        --preview-window="right:60%:wrap" \
        --bind "ctrl-d:reload($find_cmd --type d)" \
        --bind "ctrl-f:reload($find_cmd --type f)" \
        --bind "ctrl-r:reload($find_cmd)" \
    )

    # 4. SMART OPEN LOGIC
    if [[ -n "$selected" ]]; then
        if [[ -d "$selected" ]]; then
            # If Directory: CD into it and open Neovim (LazyVim will open NeoTree/Oil)
            echo "📂 Jumping to directory..."
            cd "$selected" && nvim .
        elif [[ -f "$selected" ]]; then
            # If File: CD into the file's parent directory first
            # This keeps your terminal context synced with the file you are editing.
            # local dir=$(dirname "$selected")
            # cd "$dir" && nvim "$file"

            # Open file
            echo "📝 Opening file..."
            nvim "$selected"
        fi
    fi
}

# Bind to Ctrl-O
# Widget for fop
_fop_widget() {
    fop
    zle reset-prompt
}
zle -N _fop_widget
bindkey '^o' _fop_widget


# ------------------------------------------
# TMUX KILLER (tkill)
# ------------------------------------------
tkill() {
    # 1. List sessions
    # 2. Filter out the current session (so you don't kill yourself)
    # 3. FZF to select
    local target=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | \
        grep -v "^$(tmux display-message -p '#S' 2>/dev/null)$" | \
        fzf --height=20% --layout=reverse --border --header="🔥 Select Session to KILL")

    if [[ -n "$target" ]]; then
        tmux kill-session -t "$target"
        echo "💀 Killed session: $target"
    fi
}


