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
  
  # Load secrets if variables are empty
  if [ -z "$SILO_PASS" ]; then source ~/.azure/.secrets.sh; fi

  # Set defaults if variables are still empty
  : ${SILO_HOST:="silo.postgres.database.azure.com"}
  : ${SILO_USER:="adminuser"}
  : ${SILO_DB:="postgres"}

  # Check for psql client
  if ! command -v psql &> /dev/null; then
      echo "❌ Error: 'psql' is not installed. Run: sudo dnf install postgresql"
      return 1
  fi

  # Connection Logic
  if [ -z "$1" ]; then
    # Interactive Shell
    PGPASSWORD="$SILO_PASS" psql -h "$SILO_HOST" -U "$SILO_USER" -d "$SILO_DB" -p 5432
  else
    # One-off command
    PGPASSWORD="$SILO_PASS" psql -h "$SILO_HOST" -U "$SILO_USER" -d "$SILO_DB" -p 5432 -c "$1"
  fi
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

  case "$1" in
    mount)
      if [ -d "$MOUNT_POINT" ] && mountpoint -q "$MOUNT_POINT"; then
         echo "✅ Trunk is already open."
         return
      fi

      # 1. AUTO-ENABLE VPN (Bypass ISP Block)
      echo "🛡️  Engaging Cloaking Field (Exit Node)..."
      sudo tailscale set --exit-node=station
      sleep 2

      mkdir -p "$MOUNT_POINT"
      
      echo "☁️  Opening Trunk..."
      sudo mount -t cifs "//$TRUNK_ACCOUNT.file.core.windows.net/$TRUNK_SHARE" "$MOUNT_POINT" \
        -o vers=3.0,username="$TRUNK_ACCOUNT",password="$TRUNK_KEY",dir_mode=0755,file_mode=0644,uid=$(id -u),gid=$(id -g)
      
      if mountpoint -q "$MOUNT_POINT"; then
          echo "✅ Mounted to: $MOUNT_POINT"
          echo "⚠️  VPN Active. Run 'trunk unmount' to disable."
      else
          echo "❌ Mount failed. Disabling VPN..."
          sudo tailscale set --exit-node=
      fi
      ;;
      
    unmount)
      echo "🔒 Closing Trunk..."
      
      # Only disable VPN if unmount succeeds
      if sudo umount "$MOUNT_POINT"; then
          echo "🛡️  Disengaging Cloaking Field..."
          sudo tailscale set --exit-node=
          echo "✅ Trunk closed & VPN disabled."
          
          # OPTIONAL: Remove folder only if it is truly empty/unmounted
          # rmdir "$MOUNT_POINT" 2>/dev/null 
      else
          echo "❌ Unmount failed (File in use?). VPN left ON for safety."
      fi
      ;;
      
    ls) ls -lh "$MOUNT_POINT" ;;
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
