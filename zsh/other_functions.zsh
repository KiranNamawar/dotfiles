
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
#  TAMATAR INTELLIGENCE LAYER (Groq AI)
# ==========================================

# 1. CORE FUNCTION (ask)
# The engine that powers everything else.
# Usage: ask "question"
#        ask -s "system prompt" "question"
#        echo "input" | ask "question"
ask() {
    # --- CREDENTIALS ---
    local api_key="$GROQ_API_KEY"
    if [ -z "$api_key" ] && command -v jam &> /dev/null; then
        api_key=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='GROQ_API_KEY';" 2>/dev/null)
    fi
    if [ -z "$api_key" ]; then echo "❌ Error: GROQ_API_KEY missing."; return 1; fi

    # --- FLAG PARSING ---
    local sys_prompt="You are a Linux CLI expert. Provide concise, accurate answers. Output Markdown."
    local user_prompt=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--system)
                sys_prompt="$2"
                shift 2
                ;;
            *)
                user_prompt="$1"
                shift
                ;;
        esac
    done

    # --- INPUT HANDLING (Pipe vs Arg) ---
    if [ -z "$user_prompt" ]; then
        if [ ! -t 0 ]; then
            user_prompt=$(cat) # Read piped input
        else
            echo "Usage: ask 'how do I...'"
            return 1
        fi
    fi

    # --- API REQUEST ---
    echo "🤔 Thinking..."
    
    local json_payload=$(jq -n \
        --arg content "$user_prompt" \
        --arg sys "$sys_prompt" \
        --arg model "llama-3.1-8b-instant" \
        '{
           model: $model,
           messages: [
             {role: "system", content: $sys},
             {role: "user", content: $content}
           ],
           temperature: 0.1
         }')

    local response=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    # --- OUTPUT HANDLING (Printf Safe) ---
    local answer=$(printf '%s' "$response" | jq -r '.choices[0].message.content')

    printf "\r\033[K" # Clear "Thinking..." line
    
    if [ "$answer" = "null" ]; then
        echo "❌ API Error:"
        printf '%s' "$response" | jq . 2>/dev/null
    else
        if command -v glow &> /dev/null; then
            echo "$answer" | glow -
        else
            echo "$answer"
        fi
    fi
}

# ------------------------------------------
# 2. THE CODE JANITOR (refactor)
# ------------------------------------------
# Purpose: Cleans up messy scripts, adds comments, optimizes logic.
# Usage: cat script.sh | refactor
#        refactor < script.py
refactor() {
    local sys="You are a Clean Code expert. Rewrite the provided code to be:
    1. Efficient and Secure (ShellCheck compliant).
    2. Readable (add comments explaining complex logic).
    3. Robust (add error handling).
    Output ONLY the code block."
    
    ask -s "$sys"
}

# ------------------------------------------
# 3. THE UNIVERSAL CONVERTER (morph)
# ------------------------------------------
# Purpose: Transforms data from one format to another (JSON, CSV, YAML, Table).
# Usage: vault ls | morph "json"
#        cat data.csv | morph "markdown table"
morph() {
    local target_format="$1"
    if [ -z "$target_format" ]; then echo "Usage: morph 'format' (e.g. json, csv)"; return 1; fi
    
    local sys="You are a Data Transformation Engine. Convert the input text into $target_format.
    Rules:
    - Do not summarize or explain.
    - Output ONLY the raw data in the requested format.
    - If the input is empty or invalid, return an empty string."
    
    ask -s "$sys"
}

# ------------------------------------------
# 4. THE SECURITY AUDITOR (audit)
# ------------------------------------------
# Purpose: Scans config files or scripts for security risks.
# Usage: cat /etc/ssh/sshd_config | audit
#        cat nginx.conf | audit
audit() {
    local sys="You are a Cyber Security Expert. Analyze this configuration file or script.
    Output a Checklist:
    - ❌ [CRITICAL]: List dangerous settings (e.g. root login enabled, 777 permissions).
    - ⚠️ [WARNING]: List best practices missing.
    - ✅ [SAFE]: If the file looks good.
    Be concise."
    
    ask -s "$sys"
}

# ------------------------------------------
# 5. THE DEBUGGER (why)
# ------------------------------------------
# Purpose: Explains cryptic errors and suggests fixes.
# Usage: python main.py 2>&1 | why
#        docker build . 2>&1 | why
why() {
    local sys="You are a Senior DevOps Debugger. 
    1. Analyze the error log provided.
    2. Explain the root cause in one sentence.
    3. Provide 3 specific, executable steps to fix it.
    4. If it suggests a command, wrap it in code blocks."
    
    ask -s "$sys"
}

# ------------------------------------------
# 6. GIT COMMIT (gcmt)
# ------------------------------------------
# Purpose: Writes semantic git commit messages from staged changes.
gcmt() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then echo "❌ Not a git repo."; return 1; fi
    if git diff --cached --quiet; then echo "⚠️  No staged changes."; return 1; fi

    local diff_content=$(git diff --cached --no-color --no-ext-diff | head -c 6000)
    
    # We use 'ask' here directly to reuse the API logic, but we parse the output raw
    # Note: We strip markdown code blocks in case the model adds them
    local msg=$(echo "$diff_content" | ask -s "You are a senior dev. Write a Semantic Git Commit Message. Format: <type>(<scope>): <subject>. Imperative mood. Output ONLY the raw message string." | sed 's/^```.*//g' | sed 's/```$//g' | awk '{$1=$1};1')

    if [ -z "$msg" ]; then return 1; fi

    echo ""
    echo -e "\033[1;32m$msg\033[0m"
    echo -n "🚀 Commit? [y/n/e]: "
    read -r choice
    case "$choice" in
        y|Y) git commit -m "$msg" ;;
        e|E) git commit -m "$msg" -e ;;
        *) echo "❌ Aborted." ;;
    esac
}
