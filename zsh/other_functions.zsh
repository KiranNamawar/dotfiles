
# ------------------------------------------
# NOTIFICATIONS (Ntfy.sh)
# ------------------------------------------
# Default Topic (Change this to your secret topic)
export NTFY_TOPIC="tamatar_notifications"

notify() {
    # 1. Set Defaults
    local topic="${NTFY_TOPIC}"
    local tags="tomato"
    local title=$(hostname)
    local msg_parts=()

    # 2. Parse Arguments (Allows mixing flags and message)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--topic)
                topic="$2"
                shift 2
                ;;
            -T|--tag)
                tags="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            *)
                msg_parts+=("$1")
                shift
                ;;
        esac
    done

    # 3. Construct Message
    # Join remaining arguments with space
    local msg="${msg_parts[*]}"

    # 4. Handle Piped Input (if message is still empty)
    # [ ! -t 0 ] checks if input is coming from a pipe, not the terminal
    if [ -z "$msg" ] && [ ! -t 0 ]; then
        msg=$(cat)
    fi

    # 5. Validation
    if [ -z "$msg" ]; then
        echo "Usage: notify [-t topic] [-T tag] 'Message' (or pipe)"
        echo "Example: notify -T warning 'Backup Failed'"
        return 1
    fi

    # 6. Send
    curl -s \
        -H "Title: $title" \
        -H "Tags: $tags" \
        -d "$msg" \
        "https://ntfy.sh/$topic" > /dev/null

    if [ $? -eq 0 ]; then
        echo "📨 Sent to ntfy.sh/$topic [$tags]"
    else
        echo "❌ Failed to send."
    fi
}

alias alert=notify


# ==========================================
#  TUNNEL (Public Localhost)
# ==========================================
# Usage: tunnel 3000
#        tunnel 8080
tunnel() {
    emulate -L zsh
    unsetopt monitor

    local PORT=$1
    if [ -z "$PORT" ]; then echo "Usage: tunnel <port>"; return 1; fi

    local TUNNEL_NAME="void-proxy"
    local URL="https://demo.tamatar.dev"
    local LOG_FILE="/tmp/tmt_tunnel.log"

    # --- CLEANUP HANDLER ---
    # This function runs when you hit Ctrl+C
    _tunnel_cleanup() {
        echo -e "\n🔌 Disconnecting..."
        # Kill the specific background job PID
        if [ -n "$PID" ]; then
            kill "$PID" 2>/dev/null
        fi
        rm -f "$LOG_FILE"
    }
    trap _tunnel_cleanup SIGINT SIGTERM

    echo "🚇 Routing $URL -> localhost:$PORT..."

    # 1. Start Tunnel in Background
    rm -f "$LOG_FILE"
    cloudflared tunnel run --url http://localhost:$PORT $TUNNEL_NAME > "$LOG_FILE" 2>&1 &
    local PID=$!


    # 2. Health Check (Give it 2 seconds)
    sleep 2
    if ! kill -0 $PID 2>/dev/null; then
        echo "❌ Tunnel died immediately. Logs:"
        cat "$LOG_FILE"
        # Manually trigger cleanup since trap won't fire on return
        rm -f "$LOG_FILE"
        return 1
    fi

    # 3. Success Output
    if command -v wl-copy &>/dev/null; then echo -n "$URL" | wl-copy; fi

    echo -e "🚀 \033[1;32mONLINE\033[0m"
    echo -e "🔗 \033[1;34m$URL\033[0m (Copied)"
    echo "⌨️  Press Ctrl+C to stop"

    # This allows the shell to process the trap immediately when you hit Ctrl+C
    while kill -0 $PID 2>/dev/null; do
        sleep 0.5
    done
}
