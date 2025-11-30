# ==========================================
#  AZURE UTILITIES (The "azr" Layer)
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
# 1. SILO (PostgreSQL General Purpose)
# ------------------------------------------
# Your bulk storage database.
# Usage: silo [sql_command]
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

    # Tunnel Logic (Same as before)
    if ! lsof -i :$LOCAL_PORT &>/dev/null; then
        echo "🚇 Opening tunnel via $SSH_HOST..."
        ssh -f -N -L $LOCAL_PORT:$DB_HOST:5432 $SSH_USER@$SSH_HOST
        sleep 1
    fi

    local CMD="$1"
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
                if [[ "$1" =~ "(DELETE|DROP|TRUNCATE)" ]]; then
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
# 2. HIVE (Cosmos DB / MongoDB)
# ------------------------------------------
# High-speed NoSQL Document Store
# Usage: hive [command]
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
# 3. TRUNK (Azure Files / SMB Mount)
# ------------------------------------------
# Mounts 100GB Cloud Drive to ~/trunk
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
# 4. LEDGER (Azure SQL Serverless)
# ------------------------------------------
# Microsoft SQL Server (T-SQL)
# Usage: ledger [sql]
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

# ==========================================
#  RECALL (Semantic Search / Vector DB)
# ==========================================
# Usage: recall "how do i fix wifi?"
#        recall add "Restart router to fix wifi" "manual.md"
recall() {
    local CMD="$1"
    local ARG2="$2"
    local ARG3="$3"
    
    export SILO_DB="memory"

    if ! command -v _get_embedding &>/dev/null; then
        [ -f ~/.dotfiles/zsh/ai_functions.zsh ] && source ~/.dotfiles/zsh/ai_functions.zsh
    fi

    case "$CMD" in
        clean|wipe)
            echo -n "⚠️  DANGER: Wipe ALL memory? [y/N] "
            read -r confirm
            if [[ "$confirm" == "y" ]]; then
                silo "TRUNCATE TABLE items;"
                echo "🧹 Memory wiped clean."
            else
                echo "❌ Aborted."
            fi
            ;;

        ls|log)
            echo "🔍 Recent Memories:"
            silo "SELECT id, left(content, 60) as preview, source FROM items ORDER BY id DESC LIMIT 10;"
            ;;

        add)
            if [[ -z "$ARG2" ]]; then echo "Usage: recall add <text> [source]"; return 1; fi
            local INPUT="$ARG2"
            local SOURCE="${ARG3:-manual}"
            
            echo -n "🧠 Embedding..."
            local VECTOR=$(_get_embedding "$INPUT")
            
            if [[ -z "$VECTOR" ]]; then echo "❌ Failed to generate embedding."; return 1; fi
            
            echo -n " 💾 Storing..."
            
            local B64_CONTENT=$(echo -n "$INPUT" | base64 | tr -d '\n')
            local B64_SOURCE=$(echo -n "$SOURCE" | base64 | tr -d '\n')
            
            # Use Postgres 'convert_from(decode(..., 'base64'), 'UTF8')'
            local SQL="INSERT INTO items (content, source, embedding) 
                       VALUES (
                           convert_from(decode('$B64_CONTENT', 'base64'), 'UTF8'), 
                           convert_from(decode('$B64_SOURCE', 'base64'), 'UTF8'), 
                           '$VECTOR'
                       );"
            
            if ERROR=$(silo "$SQL" 2>&1); then
                echo " ✅ Memorized."
            else
                echo " ❌ Database Error:"
                echo "$ERROR"
                return 1
            fi
            ;;

        *)
            if [[ -z "$CMD" ]]; then echo "Usage: recall <query> | add | ls | clean"; return 1; fi
            
            echo -n "🤔 Thinking..." >&2
            local QUERY_VECTOR=$(_get_embedding "$CMD")
            
            if [[ -z "$QUERY_VECTOR" ]]; then echo "❌ API Error"; return 1; fi
            
            echo -e "\r🔍 \033[1;33mRecall Results:\033[0m" >&2

            local SQL="SELECT source, content, 1 - (embedding <=> '$QUERY_VECTOR') AS similarity 
                       FROM items 
                       ORDER BY embedding <=> '$QUERY_VECTOR' 
                       LIMIT 5;"
            
            silo "$SQL" | \
            grep -v "rows)" | grep -v "^--" | grep -v "^source" | \
            awk -F '|' '{ 
                score = $3 * 100;
                if (score > 30) printf "\n👉 \033[1;36m%s\033[0m (Match: %.0f%%)\n   %s\n", $1, score, $2 
            }'
            ;;
    esac
}

# ==========================================
# REM (Remember Command)
# ==========================================
# Usage: rem "description" "command"
#        rem "description" (Saves last command)
rem() {
    local DESC="$1"
    local CMD="$2"

    if [ -z "$DESC" ]; then echo "Usage: rem <description> [command]"; return 1; fi

    # If no command provided, grab the last one from history
    if [ -z "$CMD" ]; then
        CMD=$(fc -ln -1)
    fi

    echo "💾 Remembering: $CMD"
    recall add "Command: $CMD. Description: $DESC" "shell_history"
}

# ==========================================
# OOPS (Error & Solution Memory)
# ==========================================
oops() {
    local ERROR="$1"
    local FIX="$2"
    if [ -z "$FIX" ]; then echo "Usage: oops <error_msg> <fix_command>"; return 1; fi

    echo "💊 Remembering Fix..."
    # Format: [SOLVED] Error... -> Solution...
    recall add "[SOLVED] Issue: $ERROR. Fix: $FIX" "Troubleshooting"
}

# ==========================================
# READ-PDF (Ingest PDF to Brain)
# ==========================================
read-pdf() {
    local FILE="$1"
    if [ ! -f "$FILE" ]; then echo "Usage: read-pdf <file.pdf>"; return 1; fi

    echo "📖 Reading '$FILE'..."
    # Convert PDF to text
    local TEXT=$(pdftotext "$FILE" -)

    # Chunking: Gemini can take ~1MB text, but let's take the first 4000 chars
    # to capture the abstract/summary for efficient embedding.
    local CHUNK=$(echo "$TEXT" | head -c 4000)

    echo "🧠 Memorizing..."
    recall add "Document: $(basename "$FILE"). Content: $CHUNK" "Library"
}

# ==========================================
# LOAD-ENV (Project Context)
# ==========================================
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
    
    # 2. Get Embedding (AI)
    echo -n "🧠 Embedding..."
    local VECTOR=$(_get_embedding "$FULL_TEXT")
    
    if [[ -z "$VECTOR" ]]; then echo "❌ Failed to generate embedding."; return 1; fi
    
    # 3. Prepare Content for SQL (Base64 Safe Transport)
    # We encode the text to avoid SQL injection/syntax errors with quotes
    local B64_CONTENT=$(echo -n "$FULL_TEXT" | base64 | tr -d '\n')
    local SAFE_SOURCE="Dev: $PROJ"
    
    echo -n " 💾 Storing..."
    
    # We use Postgres 'convert_from(decode(..., 'base64'), 'UTF8')' to handle the insert
    if ERROR=$(silo "INSERT INTO items (content, source, embedding) 
                     VALUES (convert_from(decode('$B64_CONTENT', 'base64'), 'UTF8'), '$SAFE_SOURCE', '$VECTOR');" 2>&1); then
        echo " ✅ Memorized."
    else
        echo " ❌ Database Error:"
        echo "$ERROR"
        return 1
    fi
}

# ------------------------------------------
# 4. SAY (AI Text-to-Speech)
# ------------------------------------------
# Usage: say "Hello World"
#        echo "Done" | say
say() {
    _az_check
    if [ -z "$SAY_KEY" ]; then source ~/.azure/.secrets.sh; fi

    local TEXT="$*"
    if [ -z "$TEXT" ] && [ ! -t 0 ]; then TEXT=$(cat); fi
    if [ -z "$TEXT" ]; then echo "Usage: say 'text'"; return 1; fi

    # 1. CLEANUP (Pandoc > Sed)
    local CLEAN_TEXT=""
    if command -v pandoc &>/dev/null; then
        CLEAN_TEXT=$(echo "$TEXT" | pandoc -f markdown -t plain --wrap=none)
    else
        CLEAN_TEXT=$(echo "$TEXT" | sed -E -e 's/\*\*//g' -e 's/^#+ //g' -e 's/\[([^]]*)\]\([^)]*\)/\1/g' -e 's/`//g')
    fi

    # 2. STREAMING AUDIO (The Hack)
    # The ( ... ) &! syntax tells Zsh: "Do this in the background and forget about it"
    if command -v mpv &>/dev/null; then
        # -s: Silent mode
        # -f: Fail silently on HTTP error (prevents playing error text as audio)
        # mpv - : Plays from Standard Input
        (
            curl -s -f -X POST "https://${SAY_REGION}.tts.speech.microsoft.com/cognitiveservices/v1" \
                -H "Ocp-Apim-Subscription-Key: $SAY_KEY" \
                -H "Content-Type: application/ssml+xml" \
                -H "X-Microsoft-OutputFormat: audio-16khz-128kbitrate-mono-mp3" \
                -d "<speak version='1.0' xml:lang='en-US'><voice xml:lang='en-US' xml:gender='Female' name='en-US-AvaMultilingualNeural'>$CLEAN_TEXT</voice></speak>" \
                | mpv --no-terminal --cache=yes - &>/dev/null
        ) &!
        # Error Check: If curl failed, the pipe was empty.
        if [ $? -ne 0 ]; then
            echo "❌ Voice Stream Failed. Check your API Key or Quota." >&2
        fi

    else
        # Fallback for systems without MPV (Use standard download method)
        (
            local AUDIO_FILE="/tmp/say_$(date +%s).mp3"
            curl -s -X POST "https://${SAY_REGION}.tts.speech.microsoft.com/cognitiveservices/v1" \
                -H "Ocp-Apim-Subscription-Key: $SAY_KEY" \
                -H "Content-Type: application/ssml+xml" \
                -H "X-Microsoft-OutputFormat: audio-16khz-128kbitrate-mono-mp3" \
                -d "<speak version='1.0' xml:lang='en-US'><voice xml:lang='en-US' xml:gender='Female' name='en-US-AvaMultilingualNeural'>$CLEAN_TEXT</voice></speak>" \
                --output "$AUDIO_FILE"

            if command -v paplay &>/dev/null; then
                paplay "$AUDIO_FILE"
            fi
            rm -f "$AUDIO_FILE"
        ) &!
    fi
}

# ------------------------------------------
# JARVIS MODE (Universal Voice Wrapper)
# ------------------------------------------
# Usage:
#   1. COMMAND: hey research "Azure"      (Runs cmd, shows output, speaks it)
#   2. PIPE:    cat error.log | hey why   (Passes input to cmd, speaks result)
#   3. CHAT:    hey "Who are you?"        (Asks AI, speaks result)
#   4. ECHO:    echo "Done" | hey         (Just speaks the input)
hey() {
    # 0. INTERCEPT "STOP" / "SHUTUP"
    if [[ "$1" == "stop" || "$1" == "shutup" || "$1" == "quiet" ]]; then
        echo "🤫 Silencing..."
        pkill mpv 2>/dev/null
        pkill paplay 2>/dev/null
        return
    fi

    local OUTPUT=""

    # --- Input Handling Logic ---
    if [ -n "$1" ]; then
        if command -v "$1" &>/dev/null; then
            echo "🤔 Running '$1'..."
            OUTPUT=$("$@")
        else
            echo "🤔 Asking AI..."
            OUTPUT=$(ask "$*")
        fi
    elif [ ! -t 0 ]; then
        OUTPUT=$(cat)
    else
        echo "Usage: hey <command> [args] OR pipe | hey [command]"
        return 1
    fi

    # 2. VALIDATION
    if [ -z "$OUTPUT" ]; then
        echo "❌ No output returned." >&2
        return 1
    fi

    # 3. VISUAL OUTPUT
    if command -v glow &>/dev/null; then
        echo "$OUTPUT" | glow -
    else
        echo "$OUTPUT"
    fi

    # 4. AUDIO OUTPUT (Streaming Voice)
    echo "$OUTPUT" | say
}


# ------------------------------------------
# SKY LAUNCHER
# ------------------------------------------
sky() {
    local AZR_LIB="${(%):-%x}"
    if [ -z "$AZR_LIB" ]; then AZR_LIB="${BASH_SOURCE[0]}"; fi

    local tools=(
        "silo:General DB (PostgreSQL)"
        "hive:NoSQL Store (Cosmos DB)"
        "trunk:100GB Cloud Drive (Mount)"
        "ledger:SQL Server (T-SQL)"
        "say:AI Voice (Text-to-Speech)"
        "hey:Jarvis Mode (Ask + Voice)"
    )

    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
            --height=50% --layout=reverse --border --header="🔷 Sky Cloud Controller" \
            --prompt="sky > " \
            --preview="awk -v func_name={1} 'BEGIN{RS=\"\"} \$0 ~ (\"(^|\\n)\" func_name \"\\\\(\\\\)\") {print}' $AZR_LIB | bat -l bash --color=always --style=numbers" \
            --preview-window="right:60%:wrap" \
        | awk '{print $1}')

    if [[ -n "$selected" ]]; then
        print -z "$selected "
    fi
}
