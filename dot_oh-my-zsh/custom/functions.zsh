# =============================================================================
# FILE AND DIRECTORY OPERATIONS
# =============================================================================

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Create file and its parent directories (use 'touchp' to avoid conflict)
touchp() {
    mkdir -p "$(dirname "$1")" && command touch "$1"
}

# Better find function using fd
find() {
    if command -v fd &> /dev/null; then
        fd "$@"
    else
        command find "$@"
    fi
}

# Quick search in current directory
search() {
    if command -v rg &> /dev/null; then
        rg -i "$@" .
    else
        grep -r -i "$@" .
    fi
}


# =============================================================================
# ARCHIVE OPERATIONS
# =============================================================================

# Universal extract function
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *.deb)       ar x "$1"        ;;
            *.tar.xz)    tar xf "$1"      ;;
            *.tar.zst)   unzstd "$1"      ;;
            *)           echo "Cannot extract $1 - unknown archive format" ;;
        esac
    else
        echo "$1 is not a valid file"
    fi
}

# Create archive from directory
mkarchive() {
    if [ -d "$1" ]; then
        case "$2" in
            tar.gz)  tar czf "${1}.tar.gz" "$1" ;;
            tar.bz2) tar cjf "${1}.tar.bz2" "$1" ;;
            zip)     zip -r "${1}.zip" "$1" ;;
            *)       echo "Usage: mkarchive <directory> <format>" ;;
        esac
    else
        echo "$1 is not a valid directory"
    fi
}


# =============================================================================
# SYSTEM INFORMATION
# =============================================================================

# Show disk usage in current directory
usage() {
    if command -v dust &> /dev/null; then
        dust
    else
        du -sh * | sort -hr
    fi
}

# Show system information
sysinfo() {
    if command -v btm &> /dev/null; then
        btm
    elif command -v htop &> /dev/null; then
        htop
    else
        top
    fi
} 


# =============================================================================
# SEARCH AND FUZZY FINDING
# =============================================================================

# Fuzzy find and edit
fe() {
    if command -v fzf &> /dev/null; then
        local file
        file=$(fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')
        [ -n "$file" ] && ${EDITOR:-vim} "$file"
    else
        echo "fzf not available"
    fi
}

# Fuzzy find directory and cd (renamed to avoid conflict with fd command)
fdir() {
    if command -v fzf &> /dev/null; then
        local dir
        dir=$(find ${1:-.} -type d 2>/dev/null | fzf +m)
        [ -n "$dir" ] && cd "$dir"
    else
        echo "fzf not available"
    fi
}

# =============================================================================
# PROCESS MANAGEMENT
# =============================================================================

# Kill process by name
killp() {
    if [ "$1" ]; then
        ps aux | grep -v grep | grep "$1" | awk '{print $2}' | xargs kill -9
    else
        echo "Usage: killp <process_name>"
    fi
}

# Interactive process killer
psk() {
    if command -v fzf &> /dev/null; then
        ps aux | fzf -m --header-lines=1 --preview 'echo {}' | awk '{print $2}' | xargs kill -9
    else
        echo "fzf not available"
    fi
}


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Password generator
genpass() {
    local length="${1:-16}"
    openssl rand -base64 "$length" | cut -c1-"$length"
}

# File backup
backup() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"
        echo "Backup created: $1.bak.$(date +%Y%m%d_%H%M%S)"
    else
        echo "$1 is not a valid file"
    fi
}

# Quit whole terminal
function q() {
    # Check if we are inside Zellij
    if [[ -n "$ZELLIJ_SESSION_ID" ]]; then
        echo "Exiting Zellij session..."
        zellij quit --force # Force quits the entire Zellij session
        sleep 0.5 # Give it a moment to detach
    fi

    # Attempt to kill the parent process (the terminal emulator)
    # This might vary depending on your terminal and how it's launched.
    # It sends a SIGTERM (graceful termination) to the parent.
    # If the parent is the terminal, it should close.
    # If it's another shell, it will exit that shell.

    # Find the parent process ID (PPID)
    local ppid=$(ps -o ppid= -p $$)

    if [[ -n "$ppid" ]]; then
        echo "Attempting to close the terminal by killing parent process $ppid..."
        kill "$ppid"
    else
        echo "Could not determine parent process ID. Falling back to 'exit'."
        exit
    fi
}
