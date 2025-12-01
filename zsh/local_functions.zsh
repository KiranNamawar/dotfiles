# ==========================================
#  LOCAL UTILITIES
# ==========================================

# ------------------------------------------
# NAME: fop
# DESC: Fuzzy Open - Find and open files in Neovim
# USAGE: fop
# TAGS: nvim, find, open
# ------------------------------------------
fop() {
    # 1. DEFINE SOURCE
    # Use 'fd' if available, otherwise 'find'
    local find_cmd
    if command -v fd &> /dev/null; then
        find_cmd="fd --type f --type d --hidden --follow --exclude .git --exclude node_modules"
    else
        find_cmd="find . -maxdepth 5 -not -path '*/.*'"
    fi

    # 2. DEFINE PREVIEW
    # If directory -> tree; If file -> bat/cat
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
# NAME: tkill
# DESC: Tmux Session Killer - Interactively kill tmux sessions
# USAGE: tkill
# TAGS: tmux, kill, session
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


# ------------------------------------------
# NAME: view
# DESC: Smart Image Viewer - Uses Kitty inline or system viewer
# USAGE: view [-g] <file>
# TAGS: image, viewer, kitty
# ------------------------------------------
view() {
    local force_gui=0
    local file=""

    # 1. Parse Flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--gui)
                force_gui=1
                shift
                ;;
            *)
                file="$1"
                shift
                ;;
        esac
    done

    if [ -z "$file" ]; then echo "Usage: view [-g] <file>"; return 1; fi

    # 2. Logic: GUI vs Inline
    if [ "$force_gui" -eq 1 ]; then
        # User explicitly asked for GUI
        xdg-open "$file" >/dev/null 2>&1
    elif [[ -n "$KITTY_PID" ]] && command -v kitten &> /dev/null; then
    # Default: Try Kitty Inline
        kitten icat "$file"
    elif command -v xdg-open &> /dev/null; then
        # Fallback: System Viewer
        xdg-open "$file" >/dev/null 2>&1
    else
        echo "❌ No image viewer found."
    fi
}


# ------------------------------------------
# NAME: ft
# DESC: Fuzzy Text Search - Live grep using ripgrep and fzf
# USAGE: ft "query" [path]
# TAGS: grep, search, find, text
# ------------------------------------------
ft() {
    # 1. Check for Ripgrep
    if ! command -v rg &> /dev/null; then
        echo "❌ Error: 'rg' (ripgrep) is missing. Install it first."
        return 1
    fi

    # 2. Parse Arguments
    local search_path="."
    local query=""
    
    if [[ -n "$*" ]] && [[ -d "${@[-1]}" ]]; then
        search_path="${@[-1]}"
        query="${@[1,-2]}"
    else
        query="$*"
    fi

    # 3. Define Commands
    # {1} = File, {2} = Line
    local preview_cmd="bat --style=numbers --color=always --highlight-line {2} {1}"
    
    local reload_cmd="rg --column --line-number --no-heading --color=always --smart-case {q} \"$search_path\""

    # 4. Run FZF
    local selected=$(fzf \
        --ansi \
        --disabled \
        --query "$query" \
        --height=80% \
        --layout=reverse \
        --border \
        --prompt="🔎 Grep [$search_path] > " \
        --delimiter : \
        --preview "$preview_cmd" \
        --preview-window="right:60%:border-left:+{2}-/2" \
        --bind "start:reload:$reload_cmd" \
        --bind "change:reload:$reload_cmd" \
        --bind "ctrl-r:reload:$reload_cmd" \
    )

    # 5. Open in Neovim
    if [[ -n "$selected" ]]; then
        local file=$(echo "$selected" | cut -d: -f1)
        local line=$(echo "$selected" | cut -d: -f2)
        
        echo "🚀 Opening $file:$line..."
        nvim "+$line" "$file"
    fi
}

# Bind to CTRL+G (Grep)
_ft_widget() { ft; zle reset-prompt; }
zle -N _ft_widget
bindkey '^g' _ft_widget


# ------------------------------------------
# NAME: ff
# DESC: Universal Finder - Find files and directories
# USAGE: ff
# TAGS: find, file, directory
# ------------------------------------------
ff() {
    local source_cmd
    if command -v fd &> /dev/null; then
        source_cmd="fd --hidden --follow --exclude .git --exclude node_modules"
    else
        source_cmd="find . -maxdepth 5 -not -path '*/.*'"
    fi

    local preview_cmd="if [ -d {} ]; then 
        lsd --tree --depth 1 --color always --icon always {}; 
    else 
        bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {}; 
    fi"

    local -a out
    out=("${(@f)$(eval "$source_cmd" | fzf \
        --layout=reverse --border --height=80% \
        --prompt="🚀 Find > " \
        --header="ENTER: Smart | ^O: GUI | ^Y: Copy | M-c: CD" \
        --preview="$preview_cmd" --preview-window="right:60%:wrap" \
        --expect="ctrl-o,ctrl-y,alt-c")}")

    # Line 1 is the key press (or empty for Enter)
    local key="${out[1]}"
    # Line 2 is the selected item
    local selected="${out[2]}"

    if [[ -z "$selected" ]]; then return; fi

    case "$key" in
        ctrl-o)
            xdg-open "$selected" >/dev/null 2>&1
            echo "🖼️  Opened: $selected"
            ;;
        ctrl-y)
            echo -n "$(readlink -f "$selected")" | (command -v wl-copy &>/dev/null && wl-copy || xclip -selection clipboard)
            echo "📋 Copied path."
            ;;
        alt-c)
            local target="$selected"
            if [[ -f "$target" ]]; then target=$(dirname "$target"); fi
            cd "$target"
            ;;
        *)
            if [[ -d "$selected" ]]; then
                cd "$selected"
            elif [[ -f "$selected" ]]; then
                echo "📝 Editing..."
                nvim "$selected"
            fi
            ;;
    esac
}

# Widget
_ff_widget() { ff; zle reset-prompt; }
zle -N _ff_widget
bindkey '^f' _ff_widget


# ------------------------------------------
# NAME: util
# DESC: Local Utilities Launcher - Menu for local tools
# USAGE: util
# TAGS: launcher, menu, tools
# ------------------------------------------
util() {
    # 1. DYNAMICALLY LOCATE THIS FILE
    local UTIL_LIB="${(%):-%x}"
    if [ -z "$UTIL_LIB" ]; then UTIL_LIB="${BASH_SOURCE[0]}"; fi

    # 2. Build Dynamic Menu
    local tools=()
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$UTIL_LIB")

    # 3. Run FZF with 'awk' Paragraph Preview
    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
        --height=50% \
        --layout=reverse \
        --border \
        --exact \
        --tiebreak=begin \
        --header="⚡ Tamatar Local Utilities" \
        --prompt="util > " \
        --delimiter="  +" \
        --with-nth=1,2 \
        --preview="awk -v func_name={1} '/^#|^[[:space:]]*$/ { buf = buf \$0 \"\\n\"; next } \$0 ~ \"^\" func_name \"\\\\(\\\\)\" { print buf \$0; in_func = 1; buf = \"\"; next } in_func { print \$0; if (\$0 ~ /^}/) exit } { buf = \"\" }' {3} | bat -l bash --color=always --style=numbers" \
        --preview-window="right:60%:wrap" \
        | awk '{print $1}')

    # 4. Push to Buffer (ZSH specific)
    if [[ -n "$selected" ]]; then
        print -z "$selected "
    fi
}

# ------------------------------------------
# NAME: jqe
# DESC: JSON Explorer - Interactive fzf-based JSON viewer
# USAGE: jqe <file> OR command | jqe
# TAGS: json, explore, fzf, view
# ------------------------------------------
jqe() {
  local INPUT_FILE=$(mktemp /tmp/jqe_XXXXXX.json)
  
  # Ensure cleanup happens on EXIT, INT (Ctrl+C), or TERM
  trap 'rm -f "$INPUT_FILE"' EXIT INT TERM

  # 1. Input Handling
  if [ -f "$1" ]; then
    cat "$1" > "$INPUT_FILE"
  elif [ -t 0 ]; then
    echo "Usage: jqe <file> OR command | jqe"
    return 1
  else
    cat > "$INPUT_FILE"
  fi

  # 2. Validity Check
  if ! jq empty "$INPUT_FILE" 2>/dev/null; then
    echo "❌ Error: Invalid JSON."
    return 1
  fi

  # 3. Explorer
  local SELECTED_PATH=$(jq -r 'paths | map(if type=="number" then "["+tostring+"]" else "[\""+tostring+"\"]" end) | join("") | "." + .' "$INPUT_FILE" \
    | fzf --height 60% --layout=reverse --border --header="JSON Explorer" --preview "jq -C {1} $INPUT_FILE")

  # 4. Output
  if [ -n "$SELECTED_PATH" ]; then
    local VALUE=$(jq -r "$SELECTED_PATH" "$INPUT_FILE")
    if command -v wl-copy &> /dev/null; then echo -n "$VALUE" | wl-copy; fi
    echo "✅ Copied: $SELECTED_PATH"
    echo "$VALUE"
  fi
}
