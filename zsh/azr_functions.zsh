# ==========================================
#  AZURE UTILITIES (The "azr" Layer)
# ==========================================
# A suite of Azure-powered CLI tools for Fedora.
#
# INFRASTRUCTURE:
# 1. Silo (PostgreSQL): General purpose bulk storage.
# 2. Hive (Cosmos DB): High-speed NoSQL document store.
# 3. Trunk (Azure Files): 100GB Cloud Drive mount.
# 4. Ledger (SQL Server): Serverless T-SQL database.
#
# AI & MEMORY:
# 5. Recall: Semantic search and vector memory.
# 6. Rem: Command history memory.
# 7. Oops: Error resolution memory.
# 8. Say: Text-to-Speech engine.
# 9. Hey: Jarvis mode (Voice wrapper).
# ==========================================


# --- CONFIGURATION ---
: ${AZ_RG:="Sky"}
: ${AZ_LOC:="centralindia"}

# --- HELPER: CHECK LOGIN ---
_az_check() {
    if ! command -v az &> /dev/null; then
        echo "❌ Azure CLI not found."
        return 1
    fi

    # Check if we have a valid account in the JSON output
    if ! az account show &>/dev/null; then
        echo "🔑 Logging into Azure..."
        az login --use-device-code
    fi
}

# ------------------------------------------
# NAME: silo
# DESC: PostgreSQL - General purpose bulk storage
# USAGE: silo [sql|backup|restore|reset]
# TAGS: db, postgres, sql, azure
# ------------------------------------------
silo() {
    _az_check
    if [ -z "$SILO_PASS" ]; then source ~/.azure/.secrets.sh; fi

    # BRIDGE CONFIG
    local SSH_USER="kiran"
    local SSH_HOST="station"
    local LOCAL_PORT="6543"

    # DB CONFIG
    local DB_HOST="silo.postgres.database.azure.com"
    local DB_USER="adminuser"
    local CURRENT_DB="${SILO_DB:-postgres}"

    if ! command -v psql &> /dev/null; then echo "❌ Error: 'psql' is missing."; return 1; fi

    local CMD="$1"

    if [[ "$CMD" == "reset" || "$CMD" == "kill" ]]; then
        local PID=$(lsof -ti :$LOCAL_PORT)
        if [ -n "$PID" ]; then
            echo "🔪 Killing tunnel on port $LOCAL_PORT (PID: $PID)..."
            kill -9 $PID
            echo "✅ Tunnel closed."
        else
            echo "💤 No active tunnel found on port $LOCAL_PORT."
        fi
        return
    fi

    # Tunnel Logic
    if ! lsof -i :$LOCAL_PORT &>/dev/null; then
        echo "🚇 Opening tunnel via $SSH_HOST..."
        ssh -f -N -L $LOCAL_PORT:$DB_HOST:5432 $SSH_USER@$SSH_HOST
        sleep 1
    fi

    export PGPASSWORD="$SILO_PASS"

    case "$CMD" in
        backup)
            # Usage: silo backup <db_name>
            # If arg provided, use it. Else use CURRENT_DB
            local TARGET="${2:-$CURRENT_DB}"
            echo "📦 Dumping '$TARGET'..." >&2
            pg_dump -h localhost -p $LOCAL_PORT -U "$DB_USER" -d "$TARGET" --no-owner --no-acl
            ;;

        restore)
            local TARGET="$2"
            if [ -z "$TARGET" ]; then echo "Usage: silo restore <db>"; return 1; fi
            echo -n "⚠️  DANGER: Overwrite '$TARGET'? [y/N] "
            read -r confirm
            if [[ "$confirm" == "y" ]]; then
                psql -h localhost -p $LOCAL_PORT -U "$DB_USER" -d "$TARGET"
            else
                echo "❌ Aborted."
            fi
            ;;

        *)
            if [ -z "$1" ]; then
                # Interactive
                psql -h localhost -p $LOCAL_PORT -U "$DB_USER" -d "$CURRENT_DB"
            else
                # One-off
                if [[ "$1" =~ (DELETE|DROP|TRUNCATE) ]] && [ -z "$SILO_FORCE" ]; then
                    echo -n "⚠️  Dangerous command. Execute? [y/N] "
                    read -r confirm
                    [[ "$confirm" != "y" ]] && echo "❌ Aborted." && return 1
                fi
                psql -h localhost -p $LOCAL_PORT -U "$DB_USER" -d "$CURRENT_DB" -c "$1"
            fi
            ;;
    esac
}

# ------------------------------------------
# NAME: hive
# DESC: Cosmos DB - NoSQL Document Store (Mongo API)
# USAGE: hive [command]
# TAGS: db, mongo, nosql, cosmos
# ------------------------------------------
hive() {
    _az_check

    # Load secrets
    if [ -z "$HIVE_URI" ]; then source ~/.azure/.secrets.sh; fi

    # Check dependencies
    if ! command -v mongosh &> /dev/null; then
        echo "❌ Error: 'mongosh' is not installed."
        return 1
    fi

    # Logic
    if [ -z "$1" ]; then
        # Interactive Shell
        mongosh "$HIVE_URI"
    else
        # One-off command (eval)
        # Example: hive "db.stats()"
        mongosh "$HIVE_URI" --quiet --eval "$1"
    fi
}

# ------------------------------------------
# NAME: trunk
# DESC: Azure Files - Mount 100GB Cloud Drive
# USAGE: trunk [mount|unmount|ls]
# TAGS: storage, mount, smb, azure
# ------------------------------------------
trunk() {
    _az_check
    if [ -z "$TRUNK_KEY" ]; then source ~/.azure/.secrets.sh; fi
    local MOUNT_POINT="$HOME/trunk"

    # Ensure mount point exists
    if [ ! -d "$MOUNT_POINT" ]; then mkdir -p "$MOUNT_POINT"; fi

    case "$1" in
        mount)
            if mountpoint -q "$MOUNT_POINT"; then
                echo "✅ Trunk is already open."
                return
            fi

            # 1. AUTO-ENABLE VPN (Bypass ISP Block)
            echo "🛡️  Engaging Cloaking Field (Exit Node)..."
            if ! sudo tailscale set --exit-node=station; then
                echo "❌ Failed to set exit node. Aborting."
                return 1
            fi

            sleep 3

            echo "☁️  Opening Trunk..."
            if sudo mount -t cifs "//$TRUNK_ACCOUNT.file.core.windows.net/$TRUNK_SHARE" "$MOUNT_POINT" \
                -o vers=3.0,username="$TRUNK_ACCOUNT",password="$TRUNK_KEY",dir_mode=0755,file_mode=0644,uid=$(id -u),gid=$(id -g); then

                echo "✅ Mounted to: $MOUNT_POINT"
                echo "⚠️  VPN ACTIVE: Internet is routing through Azure. Run 'trunk unmount' to disable."
            else
                echo "❌ Mount failed. Disabling VPN..."
                sudo tailscale set --exit-node=
            fi
            ;;

        unmount)
            echo "🔒 Closing Trunk..."

            # 1. Unmount (Lazy unmount -l prevents hanging if network is down)
            if sudo umount -l "$MOUNT_POINT"; then
                echo "✅ Unmounted."
            else
                echo "❌ Error unmounting (File in use?)."
                return 1
            fi

            # 2. Disable VPN
            echo "🛡️  Disengaging Cloaking Field..."
            sudo tailscale set --exit-node=
            echo "🌍 Local Internet Restored."
            ;;

        ls)
            if mountpoint -q "$MOUNT_POINT"; then
                echo "📂 Trunk Contents:"
                ls -lh "$MOUNT_POINT"
                echo ""
                echo "📊 Usage:"
                df -h "$MOUNT_POINT" | awk 'NR==2 {print $3 " Used / " $2 " Total (" $5 ")"}'
            else
                echo "🔒 Trunk is closed."
            fi
            ;;
        *) echo "Usage: trunk {mount | unmount | ls}" ;;
    esac
}

# ------------------------------------------
# NAME: ledger
# DESC: SQL Server - Serverless T-SQL Database
# USAGE: ledger [sql]
# TAGS: db, sql, mssql, azure
# ------------------------------------------
ledger() {
    _az_check

    if [ -z "$LEDGER_PASS" ]; then source ~/.azure/.secrets.sh; fi

    if ! command -v usql &> /dev/null; then
        echo "❌ Error: 'usql' is not installed."
        return 1
    fi

    # Set defaults if variables are still empty
    : ${LEDGER_HOST:="skyledger.database.windows.net"}
    : ${LEDGER_USER:="adminuser"}
    : ${LEDGER_DB:="ledger"}


    # Connection String (mssql protocol)
    local URI="mssql://$LEDGER_USER:$LEDGER_PASS@$LEDGER_HOST/$LEDGER_DB"

    if [ -z "$1" ]; then
        # Interactive Mode
        if ! usql "$URI" -c "SELECT 1" &>/dev/null; then
            echo "💤 Ledger is sleeping. Sending wake-up call..."
            echo "⏳ Waiting 30s for engines to spin up..."

            # Simple spinner or countdown
            for i in {30..1}; do printf "\rWaking up... %2d" $i; sleep 1; done
            echo -e "\n🚀 Ready!"
        fi
        usql "$URI"
    else
        # One-off command
        usql "$URI" -c "$1"
    fi
}

# ------------------------------------------
# NAME: rem
# DESC: Command Memory - Save command to memory
# USAGE: rem "description" [command]
# TAGS: memory, command, save, history
# ------------------------------------------
rem() {
    local DESC="$1"
    local CMD="$2"

    if [ -z "$DESC" ]; then echo "Usage: rem <description> [command]"; return 1; fi

    # If no command provided, grab the last one from history
    if [ -z "$CMD" ]; then
        CMD=$(fc -ln -1)
    fi

    echo "💾 Remembering: $CMD"
    memory add "Command: $CMD. Description: $DESC" "shell_history"
}

# ------------------------------------------
# NAME: oops
# DESC: Error Memory - Save error fix to memory
# USAGE: oops "error" "fix"
# TAGS: memory, error, fix, debug
# ------------------------------------------
oops() {
    local ERROR="$1"
    local FIX="$2"
    if [ -z "$FIX" ]; then echo "Usage: oops <error_msg> <fix_command>"; return 1; fi

    echo "💊 Remembering Fix..."
    # Format: [SOLVED] Error... -> Solution...
    memory add "[SOLVED] Issue: $ERROR. Fix: $FIX" "Troubleshooting"
}



# ------------------------------------------
# NAME: load-env
# DESC: Project Context - Index .memory file
# USAGE: load-env
# TAGS: project, context, memory, index
# ------------------------------------------
load-env() {
    if [ ! -f .memory ]; then
        echo "❌ No .memory file found in current directory."
        return 1
    fi

    local PROJ=$(basename "$PWD")
    local RAW_CONTENT=$(cat .memory)

    # 1. Prepare Text for Embedding (Needs to be plain text)
    local FULL_TEXT="Project '$PROJ' Context: $RAW_CONTENT"

    echo "🏗️  Indexing Project Context: $PROJ..."

    memory add "$FULL_TEXT" "Dev: $PROJ"
}

# ------------------------------------------
# NAME: say
# DESC: Text-to-Speech - AI Voice Output
# USAGE: say "text"
# TAGS: tts, voice, speech, ai
# ------------------------------------------
say() {
    _az_check
    if [ -z "$SAY_KEY" ]; then source ~/.azure/.secrets.sh; fi

    local TEXT="$*"
    if [ -z "$TEXT" ] && [ ! -t 0 ]; then TEXT=$(cat); fi
    if [ -z "$TEXT" ]; then echo "Usage: say 'text'"; return 1; fi

    # 1. CLEANUP: Strip ANSI Colors first, then Markdown
    local CLEAN_TEXT=""

    # Strip ANSI colors (The \e[...] stuff)
    local NO_COLOR=$(echo "$TEXT" | perl -pe 's/\e\[?.*?[\@-~]//g')

    if command -v pandoc &>/dev/null; then
        # Use Pandoc to strip Markdown (*bold*, links) into plain text
        CLEAN_TEXT=$(echo "$NO_COLOR" | pandoc -f markdown -t plain --wrap=none)
    else
        # Fallback cleanup
        CLEAN_TEXT=$(echo "$NO_COLOR" | sed -E -e 's/\*\*//g' -e 's/^#+ //g' -e 's/\[([^]]*)\]\([^)]*\)/\1/g' -e 's/`//g')
    fi

    # 2. STREAMING AUDIO
    if command -v mpv &>/dev/null; then
        (
            curl -s -f -X POST "https://${SAY_REGION}.tts.speech.microsoft.com/cognitiveservices/v1" \
                -H "Ocp-Apim-Subscription-Key: $SAY_KEY" \
                -H "Content-Type: application/ssml+xml" \
                -H "X-Microsoft-OutputFormat: audio-16khz-128kbitrate-mono-mp3" \
                -d "<speak version='1.0' xml:lang='en-US'><voice xml:lang='en-US' xml:gender='Female' name='en-US-AvaMultilingualNeural'>$CLEAN_TEXT</voice></speak>" \
                | mpv --no-terminal --cache=yes - &>/dev/null
        ) &|
    else
        echo "❌ Error: 'mpv' not installed. Cannot stream audio."
    fi
}

# ------------------------------------------
# NAME: hey
# DESC: Jarvis Mode - Universal Voice Wrapper
# USAGE: hey [command|question]
# TAGS: voice, jarvis, ai, chat
# ------------------------------------------
hey() {
    # 0. intercept "stop"
    if [[ "$1" == "stop" || "$1" == "shutup" || "$1" == "quiet" ]]; then
        echo "🤫 silencing..."
        pkill mpv 2>/dev/null
        return
    fi

    local output=""

    # --- input handling logic ---
    if [ -n "$1" ]; then
        if command -v "$1" &>/dev/null; then
            # case a: run a command (e.g., 'hey date')
            echo "🤔 running '$1'..."
            output=$("$@")
        else
            # case b: ask ai
            echo "🤔 asking..."
            output=$(ask "$*")
        fi
    elif [ ! -t 0 ]; then
        # case c: piped input (e.g., cat file | hey)
        output=$(cat)
    else
        echo "usage: hey <command/question>"
        return 1
    fi

    # 2. validation
    if [ -z "$output" ]; then
        echo "❌ no output returned." >&2
        return 1
    fi

    # 3. visual output (pretty print)
    # rask handles its own coloring, but we pipe through glow if it's raw text
    if command -v glow &>/dev/null && [ -t 1 ]; then
        # simple check: does it look like markdown?
        echo "$output" | glow - 2>/dev/null || echo "$output"
    else
        echo "$output"
    fi

    # 4. audio output (clean voice)
    # the new 'say' function strips the colors automatically
    echo "$output" | say
}

# ------------------------------------------
# NAME: sky
# DESC: Sky Launcher - Master menu for Azure tools
# USAGE: sky
# TAGS: launcher, menu, azure, tools
# ------------------------------------------
sky() {
    local AZR_LIB="${(%):-%x}"
    if [ -z "$AZR_LIB" ]; then AZR_LIB="${BASH_SOURCE[0]}"; fi

    local tools=()
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$AZR_LIB")

    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
            --height=50% \
            --layout=reverse \
            --border \
            --exact \
            --tiebreak=begin \
            --header="🔷 Sky Cloud Controller" \
            --prompt="sky > " \
            --delimiter="  +" \
            --with-nth=1,2 \
            --preview="awk -v func_name={1} '/^#|^[[:space:]]*$/ { buf = buf \$0 \"\\n\"; next } \$0 ~ \"^\" func_name \"\\\\(\\\\)\" { print buf \$0; in_func = 1; buf = \"\"; next } in_func { print \$0; if (\$0 ~ /^}/) exit } { buf = \"\" }' {3} | bat -l bash --color=always --style=numbers" \
            --preview-window="right:60%:wrap" \
        | awk '{print $1}')

    if [[ -n "$selected" ]]; then
        print -z "$selected "
    fi
}
