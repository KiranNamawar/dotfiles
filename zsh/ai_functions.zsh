# ==========================================
#  TAMATAR INTELLIGENCE LAYER
# ==========================================
# A suite of AI-powered CLI tools for Fedora.
#
# MODELS & ARCHITECTURE:
# 1. Groq Llama 3.1 8B (Fast): Used for chat, summaries, and simple text.
# 2. Groq Llama 3.3 70B (Smart): Used for coding, logic, security, and regex.
# 3. Gemini 2.5 Flash (Context): Used for huge files, images, and web search.
# ==========================================

# --- INTERNAL HELPERS (Do not call directly) ---

# 1. Credential Fetcher
_get_key() {
    local env_var="$1"
    local db_key="$2"
    local val="${(P)env_var}"
    if [ -z "$val" ] && command -v jam &> /dev/null; then
        val=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='$db_key';" 2>/dev/null)
    fi
    echo "$val"
}

# 2. Output Renderer (Handles Markdown/Glow)
_render_output() {
    local content="$1"
    printf "\r\033[K" >&2
    
    if [ -z "$content" ] || [ "$content" = "null" ]; then
        echo "❌ Error: Empty response from API." >&2
        return 1
    fi

    if command -v glow &> /dev/null && [ -t 1 ]; then
        printf '%s\n' "$content" | glow -p -
    else
        printf '%s\n' "$content"
    fi
}

# 3. Groq API Caller
# Usage: _call_groq "sys_prompt" "user_prompt" "model_id"
_call_groq() {
    local sys_prompt="$1"
    local user_prompt="$2"
    local model="$3"
    local api_key=$(_get_key "GROQ_API_KEY" "GROQ_API_KEY")

    if [ -z "$api_key" ]; then echo "❌ Error: GROQ_API_KEY missing." >&2; return 1; fi

    echo "🤔 Thinking ($model)..." >&2

    local json_payload=$(jq -n \
        --arg content "$user_prompt" \
        --arg sys "$sys_prompt" \
        --arg model "$model" \
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

    # Capture exit code of jq to detect parse failure
    local answer=$(printf '%s' "$response" | jq -r '.choices[0].message.content' 2>/dev/null)
    
    if [ -z "$answer" ] || [ "$answer" = "null" ]; then
        echo "❌ API Error:" >&2
        printf '%s' "$response" | jq . 2>/dev/null >&2 || echo "$response" >&2
        return 1
    fi
    
    echo "$answer"
}

# 4. Gemini API Caller
_call_gemini() {
    local sys_prompt="$1"
    local user_prompt="$2"
    local tools="$3"
    local api_key=$(_get_key "GEMINI_API_KEY" "GEMINI_API_KEY")

    if [ -z "$api_key" ]; then echo "❌ Error: GEMINI_API_KEY missing." >&2; return 1; fi

    echo "♊ Gemini is reasoning..." >&2

    local json_payload=$(jq -n \
        --arg sys "$sys_prompt" \
        --arg user "$user_prompt" \
        '{
          system_instruction: { parts: [{ text: $sys }] },
          contents: [{ parts: [{ text: $user }] }]
        }')

    if [ -n "$tools" ]; then
        json_payload=$(printf '%s' "$json_payload" | jq --argjson t "$tools" '. + {tools: $t}')
    fi

    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    local answer=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text')
    
    if [ -z "$answer" ] || [ "$answer" = "null" ]; then
        echo "❌ API Error:" >&2
        printf '%s' "$response" | jq . 2>/dev/null >&2
        return 1
    fi

    echo "$answer"
}


# --- PUBLIC FUNCTIONS ---

# 1. ASK
# Purpose: General purpose Q&A for Linux/Coding.
# Model: Llama 3.1 8B (Fastest response)
# Usage: ask "how do I unzip tar.gz"
#        echo "error text" | ask "explain this"
ask() {
    local sys_prompt="You are a Linux CLI expert. Provide concise, accurate answers. Output Markdown."
    local user_prompt=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--system) sys_prompt="$2"; shift 2 ;;
            *) user_prompt="$1"; shift ;;
        esac
    done

    if [ -z "$user_prompt" ] && [ ! -t 0 ]; then user_prompt=$(cat); fi
    if [ -z "$user_prompt" ]; then echo "Usage: ask 'question'"; return 1; fi

    local result=$(_call_groq "$sys_prompt" "$user_prompt" "llama-3.1-8b-instant")
    _render_output "$result"
}

# 2. REFACTOR
# Purpose: Rewrites code to be cleaner, secure, and documented.
# Model: Llama 3.3 70B (Smart logic needed)
# Usage: cat script.sh | refactor
#        refactor < script.py
refactor() {
    local input="${1:-$(cat)}"
    if [ -z "$input" ]; then echo "Usage: refactor < file"; return 1; fi
    
    local sys="You are a Clean Code Expert. Rewrite the provided code to be Efficient, Secure, and Readable. Add comments. Output ONLY the code block."
    local result=$(_call_groq "$sys" "$input" "llama-3.3-70b-versatile")
    _render_output "$result"
}

# 3. MORPH
# Purpose: Converts data formats (JSON <-> CSV <-> YAML <-> Tables).
# Model: Llama 3.3 70B (Smart instruction following)
# Usage: cat data.csv | morph "json"
#        vault ls | morph "markdown table"
morph() {
    local target="$1"
    local input="${2:-$(cat)}"
    if [ -z "$target" ]; then echo "Usage: morph 'format' < input"; return 1; fi

    local sys="You are a Data Transformation Engine. Convert input to $target. Output raw data only. No markdown blocks."
    local result=$(_call_groq "$sys" "$input" "llama-3.3-70b-versatile")
    
    # Output raw for piping
    printf "\r\033[K" >&2
    echo "$result"
}

# 4. AUDIT
# Purpose: Scans configs for security risks.
# Model: Llama 3.3 70B (Smart reasoning)
# Usage: cat nginx.conf | audit
#        cat /etc/ssh/sshd_config | audit
audit() {
    local input="${1:-$(cat)}"
    local sys="You are a Security Auditor. Scan for vulnerabilities. Output a Checklist: ❌ CRITICAL, ⚠️ WARNING, ✅ SAFE."
    local result=$(_call_groq "$sys" "$input" "llama-3.3-70b-versatile")
    _render_output "$result"
}

# 5. WHY
# Purpose: Explains errors and provides fixes.
# Model: Llama 3.3 70B (Smart debugging)
# Usage: python main.py 2>&1 | why
#        docker build . 2>&1 | why
why() {
    local input="${1:-$(cat)}"
    local sys="You are a Senior Debugger. Explain the error root cause in 1 sentence. Provide 3 fix steps."
    local result=$(_call_groq "$sys" "$input" "llama-3.3-70b-versatile")
    _render_output "$result"
}

# 6. SUMMARIZE
# Purpose: Condenses logs or long text into bullet points.
# Model: Llama 3.1 8B (Fast compression)
# Usage: cat access.log | summarize
summarize() {
    local input="${1:-$(cat)}"
    local sys="Summarize into 3-5 bullet points. Capture key technical details."
    local result=$(_call_groq "$sys" "$input" "llama-3.1-8b-instant")
    _render_output "$result"
}

# 7. GCMT (Git Commit)
# Purpose: Writes semantic commit messages based on diffs.
# Model: Gemini 2.5 Flash (Massive Context for large diffs)
# Usage: gcmt (inside git repo)
gcmt() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then echo "❌ Not a git repo."; return 1; fi
    if git diff --cached --quiet; then echo "⚠️  No staged changes."; return 1; fi

    local branch=$(git branch --show-current)
    local diff_content=$(git diff --cached --no-color --no-ext-diff | head -c 100000)
    local sys="You are an expert Git Release Manager who writes high-quality Semantic Commit Messages. 
      Your output MUST adhere strictly to the following rules:
      1.  **Format:** <type>(<scope>): <subject> followed by an optional blank line and a detailed body.
      2.  **Style:** Use the Imperative Mood (e.g., 'Fix bug', not 'Fixed bug').
      3.  **Length/Detail:**
          * For **large, complex, or multi-component** changes, include a **detailed, paragraph-based message body** after the subject line explaining the *why* and *how*. Use markdown bullet points in the body if needed.
          * For **small, simple** changes, output only the single line <type>(<scope>): <subject>.
      4.  **Output:** Provide ONLY the raw, unquoted commit message string. Do NOT add any conversational text or explanation."

    local user_prompt="Current Branch: $branch\n\nCode Changes:\n$diff_content"
    
    local msg=$(_call_gemini "$sys" "$user_prompt")
    msg=$(echo "$msg" | sed 's/^```.*//g' | sed 's/```$//g' | awk '{$1=$1};1')
    
    if [ -z "$msg" ]; then return 1; fi
    
    printf "\r\033[K" >&2 
    echo -e "\033[1;32m$msg\033[0m"
    echo -n "🚀 Commit? [y/n/e]: "
    read -r choice
    case "$choice" in
        y|Y) git commit -m "$msg" ;;
        e|E) git commit -m "$msg" -e ;;
        *) echo "❌ Aborted." ;;
    esac
}

# 8. GURU
# Purpose: Context-aware project architect. Knows your file structure.
# Model: Gemini 2.5 Flash (Context + Search)
# Usage: guru "How do I run this?"
#        guru -f main.rs "Refactor this file"
guru() {
    local context_files=""
    local user_prompt=""
    local context_tree=""
    
    if command -v lsd &> /dev/null; then
        context_tree=$(lsd --tree --depth 2 --group-directories-first --ignore-glob .git --ignore-glob node_modules --color=never)
    else
        context_tree=$(find . -maxdepth 2 -not -path '*/.*')
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                if [ -f "$2" ]; then
                    context_files+="\n--- FILE: $2 ---\n$(command cat "$2")\n"
                    shift 2
                else
                    echo "⚠️  File not found: $2"
                    shift
                fi
                ;;
            *) user_prompt="$1"; shift ;;
        esac
    done
    if [ -z "$user_prompt" ]; then echo "Usage: guru [-f file] 'Question'"; return 1; fi

    local sys="You are the Lead Architect.
    [[ STRUCTURE ]]
    $context_tree
    [[ FILES ]]
    $context_files
    Task: Answer based on context. Use Google Search if needed."

    local result=$(_call_gemini "$sys" "$user_prompt" '[{ "google_search": {} }]')
    _render_output "$result"
}

# 9. VISION
# Purpose: Analyze images/screenshots.
# Model: Gemini 2.5 Flash (Multimodal)
# Usage: vision screenshot.png "What is the error here?"
vision() {
    local api_key=$(_get_key "GEMINI_API_KEY" "GEMINI_API_KEY")
    if [ -z "$api_key" ]; then echo "❌ Error: GEMINI_API_KEY missing."; return 1; fi

    local file_path="$1"
    local user_prompt="${2:-Analyze this file in detail.}"
    
    if [ -z "$file_path" ]; then echo "Usage: vision <file> [prompt]"; return 1; fi
    if [ ! -f "$file_path" ]; then echo "❌ File not found."; return 1; fi

    echo "👀 Analyzing..." >&2
    local mime_type=$(file --mime-type -b "$file_path")
    
    # 1. Create a temporary file for the JSON payload
    local payload_file=$(mktemp /tmp/gemini_payload_XXXXXX.json)

    # 2. Construct JSON Streamingly (Bypasses ARG_MAX limit)
    # We pipe base64 -> jq (as raw input) -> file
    # The '.' in jq represents the incoming base64 string
    if [[ "$OSTYPE" == "darwin"* ]]; then
        base64 -i "$file_path"
    else
        base64 -w0 "$file_path"
    fi | jq -R --arg text "$user_prompt" --arg mime "$mime_type" \
        '{ contents: [{ parts: [{text: $text}, {inline_data: {mime_type: $mime, data: .}}] }] }' \
        > "$payload_file"

    # 3. Send Request using File Reference (@file)
    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "@$payload_file")

    # 4. Cleanup
    rm "$payload_file"

    # 5. Output
    local answer=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text')
    _render_output "$answer"
}

# 10. RESEARCH
# Purpose: Search the live web for current info.
# Model: Gemini 2.5 Flash (Web Grounding)
# Usage: research "Fedora 41 release date"
research() {
    local prompt="$*"
    if [ -z "$prompt" ]; then echo "Usage: research 'topic'"; return 1; fi
    local result=$(_call_gemini "You are a Research Assistant. Use Google Search." "$prompt" '[{ "google_search": {} }]')
    _render_output "$result"
}

# 11. RX (Regex Generator)
# Purpose: Generates complex regex patterns.
# Model: Llama 3.3 70B (High Logic)
# Usage: rx "email address"
#        grep -E $(rx "phone number") file.txt
rx() {
    local input="$*"
    if [ -z "$input" ]; then echo "Usage: rx 'pattern description'"; return 1; fi
    local sys="You are a Regex Generator. Output ONLY the Regular Expression string. Use PCRE flavor."
    
    local result=$(_call_groq "$sys" "$input" "llama-3.3-70b-versatile")
    
    # Output only the raw regex for piping
    printf "\r\033[K" >&2
    echo "$result"
}

# 12. PICK (Extractor)
# Purpose: Extracts specific data from messy text.
# Model: Llama 3.3 70B (High Logic)
# Usage: cat logs | pick "IP addresses"
pick() {
    local target="$1"
    local input="${2:-$(cat)}"
    if [ -z "$target" ]; then echo "Usage: pick 'what to extract' < input"; return 1; fi
    
    local sys="You are a Data Extraction Engine. Extract ONLY the entities requested. List format. No explanations. No Formating."
    local result=$(_call_groq "$sys" "Target: $target\n\nInput:\n$input" "llama-3.3-70b-versatile")
    
    printf "\r\033[K" >&2
    echo "$result"
}

# 13. EXPLAIN (Decoder)
# Purpose: Breaks down complex commands or regex.
# Model: Llama 3.3 70B (High Logic)
# Usage: explain "chmod 755"
explain() {
    local input="${1:-$(cat)}"
    local sys="You are a Technical Educator. Explain the code/command component by component. Be concise."
    local result=$(_call_groq "$sys" "$input" "llama-3.3-70b-versatile")
    _render_output "$result"
}

# ------------------------------------------
# 14. JSQL (Jam SQL Generator)
# ------------------------------------------
# Purpose: Generates strict SQL for MySQL (Jam) based on actual schema.
# Model: Llama 3.3 70B (Logic)
# Usage: jsql "show tasks pending"
#        jsql -d my_app "count active users"
#        jam -e "$(jsql "delete old logs")"
jsql() {
    local target_db="utils"
    local user_prompt=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--database) target_db="$2"; shift 2 ;;
            *) user_prompt="$1"; shift ;;
        esac
    done

    if [ -z "$user_prompt" ]; then echo "Usage: jsql [-d database] 'query description'"; return 1; fi
    
    echo "🧠 Reading schema from '$target_db'..." >&2
    
    local query="SELECT CONCAT(TABLE_NAME, ' (', GROUP_CONCAT(COLUMN_NAME SEPARATOR ', '), ')') 
                 FROM information_schema.COLUMNS 
                 WHERE TABLE_SCHEMA = '$target_db' 
                 GROUP BY TABLE_NAME;"
                 
    local current_schema=$(jam -N -B -e "$query" 2>/dev/null)
    
    if [ -z "$current_schema" ]; then
        echo "⚠️  Warning: Could not fetch schema. AI will guess." >&2
        current_schema="[Unknown]"
    fi

    local sys="You are a MySQL Query Generator.
    Rules:
    1. Output ONLY valid SQL. No markdown.
    2. Use STRICTLY the schema below.
    3. ALWAYS use fully qualified table names (e.g., '$target_db.tablename').
    4. Target Database: $target_db
    5. If the user asks for 'all tables', 'list tables', or 'show tables', output a metadata query (e.g., SHOW TABLES or SELECT FROM information_schema). DO NOT use SELECT *.
    6. Do NOT use 'UNION' unless tables have identical schema.
    7. Output a SINGLE executable statement. Do not generate multiple queries.

    [[ SCHEMA ]]
    $current_schema"
    
    local result=$(_call_groq "$sys" "$user_prompt" "llama-3.3-70b-versatile")
    
    # Cleanup
    result=$(echo "$result" | sed 's/^```sql//g' | sed 's/^```//g' | sed 's/```$//g' | awk '{$1=$1};1')
    
    echo "$result"
}

# ------------------------------------------
# 15. JASK (Generate & Execute SQL)
# ------------------------------------------
# Purpose: Generates SQL via AI, confirms with user, then runs it on Jam.
# Model: Llama 3.3 70B (via jsql)
# Usage: jask "show 5 newest tasks"
#        jask -d my_db "count users"
jask() {
    # Pass all arguments to jsql to handle flags like -d
    local sql=$(jsql "$@")

    if [ -z "$sql" ]; then return 1; fi

    # Interactive Review
    echo ""
    echo "📜 Generated SQL:"
    # Print in Yellow for visibility
    echo -e "\033[1;33m$sql\033[0m"
    echo ""

    echo -n "🚀 Run on Jam? [y/N] "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Check if arguments included a -d flag to pick the right DB for execution
        # A simple regex check to see if a specific DB was requested in the args
        # (This is optional optimization, jam usually runs query directly)
        jam -e "$sql"
    else
        echo "❌ Aborted."
    fi
}

# ------------------------------------------
# 15. JQ GENERATOR (jqg)
# ------------------------------------------
# Purpose: Generates complex JQ filters from natural language.
# Model: Llama 3.3 70B (Logic)
# Usage: jqg "get all values of key 'id'"
#        head -n 20 data.json | jqg "extract users with role admin"
jqg() {
    local goal="$*"
    local json_context=""

    # 1. Check for Piped Input (Context)
    # If user pipes data, we read the first 20 lines to understand the schema
    if [ ! -t 0 ]; then
        json_context=$(head -n 20)
    fi

    if [ -z "$goal" ]; then
        echo "Usage: jqg 'description of filter'"
        echo "Tip: Pipe JSON sample for better accuracy: head file.json | jqg '...'"
        return 1
    fi

    # 2. Construct System Prompt
    local sys="You are a JQ Filter Generator.
    Rules:
    1. Output ONLY the raw jq filter string.
    2. No markdown (no \`\`\`), no quotes, no explanations.
    3. If JSON context is provided, use specific key names.
    4. If context is missing, infer standard keys."

    local user_prompt="Goal: $goal"
    if [ -n "$json_context" ]; then
        user_prompt="$user_prompt\n\nJSON Sample:\n$json_context"
    fi

    # 3. Call Groq 70B
    local result=$(_call_groq "$sys" "$user_prompt" "llama-3.3-70b-versatile")
    
    # 4. Cleanup Output
    result=$(echo "$result" | sed 's/^```jq//g' | sed 's/^```//g' | sed 's/```$//g' | awk '{$1=$1};1')
    
    echo "$result"
}

# ------------------------------------------
# 16. JQA (Generate & Apply JQ)
# ------------------------------------------
# Purpose: Pipes JSON, asks AI for a filter, and executes it immediately.
# Usage: cat file.json | jqa "get all users"
#        curl api | jqa "extract only the id and status"
jqa() {
    local goal="$1"
    if [ -z "$goal" ]; then echo "Usage: cat file.json | jqa 'filter description'"; return 1; fi
    
    # 1. Buffer Input
    # We need the data twice: once for context (head) and once for execution (jq)
    local tmp_file=$(mktemp /tmp/jqa_XXXXXX.json)
    cat > "$tmp_file"
    
    # Safety check: is it valid JSON?
    if ! jq empty "$tmp_file" 2>/dev/null; then
        echo "❌ Error: Input is not valid JSON." >&2
        rm "$tmp_file"
        return 1
    fi

    # 2. Generate Filter
    # We pipe the first 20 lines to your existing 'jqg' function to get the smart filter
    local filter=$(head -n 20 "$tmp_file" | jqg "$goal")
    
    if [ -z "$filter" ]; then 
        echo "❌ Failed to generate filter." >&2
        rm "$tmp_file"
        return 1 
    fi

    # 3. Feedback (Stderr so it doesn't break pipes)
    echo "🔍 Filter: $filter" >&2

    # 4. Execute
    jq "$filter" "$tmp_file"
    
    # Cleanup
    rm "$tmp_file"
}

# ------------------------------------------
# 17. SEARCH (Smart Polyglot Finder)
# ------------------------------------------
search() {
    local description="$*"
    if [ -z "$description" ]; then echo "Usage: search 'description'"; return 1; fi

    local sys="You are a Command Line Search Expert.
    Task: Translate the request into a single 'fd' or 'rg' command.
    Rules:
    1. If searching for **File Names** or attributes, use 'fd'.
    2. If searching for **Text Content** inside files, use 'rg -l' (list filenames only).
    3. Do NOT use 'find', '-exec', or 'xargs'. Use only standalone 'fd' or 'rg' flags.
    4. Target the CURRENT DIRECTORY ('.') unless a path is explicitly requested.
    5. Output ONLY the raw command string."

    local cmd=$(_call_groq "$sys" "Find: $description" "llama-3.3-70b-versatile")
    cmd=$(echo "$cmd" | sed 's/^```.*//g' | sed 's/```$//g' | awk '{$1=$1};1')

    if [ -z "$cmd" ]; then echo "❌ Failed."; return 1; fi
    echo "🤖 Command: $cmd" >&2
    
    local preview_cmd="if [ -d {} ]; then 
        lsd --tree --depth 1 --color always --icon always {}; 
    else 
        bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {}; 
    fi"

    # Capture output into array
    local -a out
    out=("${(@f)$(eval "$cmd" | fzf \
        --layout=reverse --border --height=80% \
        --prompt="🕵️  Search > " \
        --header="ENTER: Smart | ^O: GUI | ^Y: Copy | M-c: CD" \
        --preview="$preview_cmd" --preview-window="right:60%:wrap" \
        --expect="ctrl-o,ctrl-y,alt-c")}")

    local key="${out[1]}"
    local selected="${out[2]}"

    if [[ -z "$selected" ]]; then return; fi

    case "$key" in
        ctrl-o) xdg-open "$selected" >/dev/null 2>&1 ;;
        ctrl-y) echo -n "$(readlink -f "$selected")" | (command -v wl-copy &>/dev/null && wl-copy || xclip -selection clipboard) ;;
        alt-c)  
            local target="$selected"
            if [[ -f "$target" ]]; then target=$(dirname "$target"); fi
            cd "$target" ;;
        *)
            if [[ -d "$selected" ]]; then cd "$selected"; 
            elif [[ -f "$selected" ]]; then echo "📝 Editing..."; nvim "$selected"; fi 
            ;;
    esac
}


# ==========================================
#  AI LAUNCHER (The Master Menu)
# ==========================================
# Usage: ai
ai() {
    # 1. Define Location (Adjust if your dotfiles are elsewhere!)
    local AI_LIB="$HOME/.dotfiles/zsh/ai_functions.zsh"

    # 2. Define the menu
    local tools=(
        "ask:General Q&A (Groq 8B)"
        "refactor:Clean & Optimize Code (Groq 70B)"
        "morph:Convert Data Formats (Groq 70B)"
        "audit:Security Config Scanner (Groq 70B)"
        "why:Debug Errors & Stacktraces (Groq 70B)"
        "summarize:Summarize Logs/Text (Groq 8B)"
        "gcmt:Write Semantic Git Commits (Gemini)"
        "guru:Context-Aware Architect (Gemini)"
        "vision:Analyze Images/Screenshots (Gemini)"
        "research:Live Web Search (Gemini)"
        "rx:Generate Regex Patterns (Groq 70B)"
        "pick:Extract Data from Messy Text (Groq 70B)"
        "explain:Explain Code/Commands (Groq 70B)"
        "jsql:Generate MySQL Queries (Groq 70B)"
        "jask:Generate & Run MySQL Query (Interactive)"
        "jqg:Generate JQ Filter (Groq 70B)"
        "jqa:Generate & Apply JQ Filter"
        "search:AI File Finder (Groq 70B)"
    )

    # 3. Run FZF with File-Based Preview
    # The awk command reads the file in 'Paragraph Mode' (RS="")
    # It prints the paragraph that contains "function_name()"
    # This captures the comments above the function because there is no blank line between them.
    
    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
        --height=60% \
        --layout=reverse \
        --border \
        --header="🤖 Tamatar Intelligence Layer" \
        --prompt="Select Tool > " \
        --preview="awk -v func_name={1} 'BEGIN{RS=\"\"} \$0 ~ (\"(^|\\n)\" func_name \"\\\\(\\\\)\") {print}' $AI_LIB | bat -l zsh --color=always --style=numbers" \
        --preview-window="right:65%:wrap" \
        | awk '{print $1}')

    # 4. Push to Buffer
    if [[ -n "$selected" ]]; then
        print -z "$selected "
    fi
}
