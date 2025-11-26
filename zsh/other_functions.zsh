
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

