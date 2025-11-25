
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
    # Send "Thinking" to stderr (>&2) so it is NOT captured by variables
    echo "🤔 Thinking..." >&2

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

    # Clear the "Thinking" line on stderr
    printf "\r\033[K" >&2
    
    if [ "$answer" = "null" ]; then
        echo "❌ API Error:"
        printf '%s' "$response" | jq . 2>/dev/null
    else
      if command -v glow &> /dev/null && [ -t 1 ]; then
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


# ==========================================
#  GEMINI VISION (gemini-2.5-flash)
# ==========================================
# Usage: vision image.png "Explain this"
#        vision document.pdf "Summarize this"
vision() {
    # 1. Credentials
    local api_key="$GEMINI_API_KEY"
    if [ -z "$api_key" ] && command -v jam &> /dev/null; then
        api_key=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='GEMINI_API_KEY';" 2>/dev/null)
    fi
    if [ -z "$api_key" ]; then echo "❌ Error: GEMINI_API_KEY missing."; return 1; fi

    local file_path="$1"
    local user_prompt="${2:-Analyze this file in detail.}"

    if [ -z "$file_path" ]; then echo "Usage: vision <file> [prompt]"; return 1; fi
    if [ ! -f "$file_path" ]; then echo "❌ File not found: $file_path"; return 1; fi

    # 2. Detect Mime Type (PDF or Image)
    local mime_type=$(file --mime-type -b "$file_path")
    echo "👀 Analyzing ($mime_type)..."

    # 3. Prepare Data (Base64)
    local b64_data
    if [[ "$OSTYPE" == "darwin"* ]]; then
        b64_data=$(base64 -i "$file_path")
    else
        b64_data=$(base64 -w0 "$file_path")
    fi

    # 4. JSON Payload
    local json_payload=$(jq -n \
        --arg text "$user_prompt" \
        --arg data "$b64_data" \
        --arg mime "$mime_type" \
        '{
          contents: [{
            parts: [
              {text: $text},
              {inline_data: {mime_type: $mime, data: $data}}
            ]
          }]
        }')

    # 5. Send to Gemini 2.5 Flash
    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    # 6. Output
    local answer=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text')

    printf "\r\033[K"
    if [ "$answer" = "null" ] || [ -z "$answer" ]; then
        echo "❌ API Error:"
        printf '%s' "$response" | jq . 2>/dev/null
    else
        if command -v glow &> /dev/null; then echo "$answer" | glow -; else echo "$answer"; fi
    fi
}


# ==========================================
#  GEMINI RESEARCH (Live Web Search)
# ==========================================
# Usage: research "Current price of RTX 4090 in India"
#        research "Who won the cricket match yesterday?"
research() {
    local api_key="$GEMINI_API_KEY"
    if [ -z "$api_key" ] && command -v jam &> /dev/null; then
        api_key=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='GEMINI_API_KEY';" 2>/dev/null)
    fi
    
    local prompt="$*"
    if [ -z "$prompt" ]; then echo "Usage: research 'question'"; return 1; fi

    echo "🌍 Searching Google & Reasoning..."

    # We inject the "googleSearch" tool into the request
    local json_payload=$(jq -n \
        --arg text "$prompt" \
        '{
          contents: [{ parts: [{text: $text}] }],
          tools: [{ google_search: {} }] 
        }')

    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    local answer=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text')

    printf "\r\033[K"
    if [ "$answer" = "null" ]; then
        echo "❌ API Error:"
        printf '%s' "$response" | jq .
    else
        if command -v glow &> /dev/null; then echo "$answer" | glow -; else echo "$answer"; fi
    fi
}


# ==========================================
#  TAMATAR GURU (Context-Aware Architect)
# ==========================================
# Model: gemini-2.5-flash
# Features: Directory Awareness + Web Search + File Ingestion
# Usage:
#   guru "What does this project do?" (Scans file tree automatically)
#   guru -f main.rs "Refactor this" (Reads file)
#   guru "Latest Fedora release?" (Searches Google)
guru() {
    # 1. Credentials
    local api_key="$GEMINI_API_KEY"
    if [ -z "$api_key" ] && command -v jam &> /dev/null; then
        api_key=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='GEMINI_API_KEY';" 2>/dev/null)
    fi
    if [ -z "$api_key" ]; then echo "❌ Error: GEMINI_API_KEY missing."; return 1; fi

    # 2. Context Gathering (The "Out of Box" Magic)
    local context_files=""
    local user_prompt=""
    local context_tree=""

    # Automatic: Generate a map of the current territory (max 3 levels deep)
    # This tells Gemini WHERE it is (e.g., "I see a src/ folder and a cargo.toml, this is Rust")
    if command -v lsd &> /dev/null; then
        context_tree=$(lsd --tree --depth 2 --group-directories-first --ignore-glob .git --ignore-glob node_modules)
    else
        context_tree=$(find . -maxdepth 2 -not -path '*/.*')
    fi

    # 3. Argument Parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                # Ingest a specific file into context
                if [ -f "$2" ]; then
                    context_files+="\n--- FILE: $2 ---\n$(cat -pP "$2")\n"
                    shift 2
                else
                    echo "⚠️  File not found: $2"
                    shift
                fi
                ;;
            *)
                user_prompt="$1"
                shift
                ;;
        esac
    done

    if [ -z "$user_prompt" ]; then echo "Usage: guru [-f file.txt] 'Question'"; return 1; fi

    echo "🧠 Guru is meditating on your context..."

    # 4. Construct System Prompt with Context
    # We feed the directory tree into the prompt so Gemini understands the project structure.
    local system_context="You are the Tech Lead of this project.
    
    [[ CURRENT DIRECTORY STRUCTURE ]]
    $context_tree
    
    [[ LOADED FILES ]]
    $context_files
    
    Task: Answer the user request based on this structure and file content.
    If you need outside info, use the Google Search tool."

    # 5. JSON Payload (with Google Search Tool Enabled)
    local json_payload=$(jq -n \
        --arg sys "$system_context" \
        --arg user "$user_prompt" \
        '{
          system_instruction: { parts: [{ text: $sys }] },
          contents: [{ parts: [{ text: $user }] }],
          tools: [{ google_search: {} }]
        }')

    # 6. Send to Gemini 2.5 Flash
    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    # 7. Output Parsing
    local answer=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text')

    printf "\r\033[K"
    if [ "$answer" = "null" ]; then
        echo "❌ Guru is silent (API Error):"
        printf '%s' "$response" | jq . 2>/dev/null
    else
        echo "🧘"
        if command -v glow &> /dev/null; then
            echo "$answer" | glow -
        else
            echo "$answer"
        fi
    fi
}


# ==========================================
#  TAMATAR PAINT
# ==========================================
# Usage: paint "A cyber tomato"
paint() {
    local prompt="$1"
    local output="art_$(date +%s).jpg"
    
    # 1. Credentials
    local token="$HF_TOKEN" 
    if [ -z "$token" ] && command -v jam &> /dev/null; then
        token=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='HF_TOKEN';" 2>/dev/null)
    fi
    if [ -z "$token" ]; then echo "❌ Error: HF_TOKEN missing."; return 1; fi
    if [ -z "$prompt" ]; then echo "Usage: paint 'prompt'"; return 1; fi

    echo "🎨 Painting with FLUX.1-schnell..."

    # 2. Request (Binary Mode)
    curl -s -D /tmp/hf_headers.txt -X POST \
        "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{\"inputs\": \"$prompt\"}" \
        --output "$output"

    # 3. Check Success (Robust grep)
    # Matches "HTTP/1.1 200 OK" OR "HTTP/2 200"
    if grep -qE "HTTP/[0-9.]+ 200" /tmp/hf_headers.txt; then
        echo "🖼️  Saved to $output"
        
        # Optional: Show Quota if headers exist
        local remaining=$(grep -i "x-ratelimit-remaining" /tmp/hf_headers.txt | awk '{print $2}' | tr -d '\r')
        if [ -n "$remaining" ]; then
            echo "📊 Quota: $remaining"
        fi
    else
        echo "❌ Error:"
        head -n 1 /tmp/hf_headers.txt
        rm "$output" 2>/dev/null
    fi
}
