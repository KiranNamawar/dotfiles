# ==========================================
#  TAMATAR INTELLIGENCE LAYER (v2.0)
# ==========================================
# Models:
#   - Logic:   Groq / llama-3.3-70b-versatile (Smartest, 12k TPM)
#   - Context: Gemini / gemini-2.5-flash      (1M Context, Free)
# ==========================================

# --- INTERNAL HELPERS ---

# 1. Credential Fetcher (DRY Principle)
_get_key() {
    local env_var="$1"
    local db_key="$2"
    local val="${(P)env_var}" # Read env var value indirectly
    
    if [ -z "$val" ] && command -v jam &> /dev/null; then
        val=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='$db_key';" 2>/dev/null)
    fi
    echo "$val"
}

# 2. Groq API Caller
_call_groq() {
    local sys_prompt="$1"
    local user_prompt="$2"
    local model="${3:-llama-3.3-70b-versatile}" 

    local api_key=$(_get_key "GROQ_API_KEY" "GROQ_API_KEY")
    if [ -z "$api_key" ]; then echo "❌ Error: GROQ_API_KEY missing."; return 1; fi

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

    local answer=$(printf '%s' "$response" | jq -r '.choices[0].message.content')
    printf "\r\033[K" >&2

    if [ "$answer" = "null" ]; then
        echo "❌ API Error:" >&2
        printf '%s' "$response" | jq . 2>/dev/null >&2
        return 1
    fi
    
    echo "$answer"
}

# 3. Gemini API Caller
_call_gemini() {
    local sys_prompt="$1"
    local user_prompt="$2"
    local tools="$3" # Optional JSON string for tools

    local api_key=$(_get_key "GEMINI_API_KEY" "GEMINI_API_KEY")
    if [ -z "$api_key" ]; then echo "❌ Error: GEMINI_API_KEY missing."; return 1; fi

    echo "♊ Gemini is reasoning..." >&2

    local json_payload=$(jq -n \
        --arg sys "$sys_prompt" \
        --arg user "$user_prompt" \
        '{
          system_instruction: { parts: [{ text: $sys }] },
          contents: [{ parts: [{ text: $user }] }]
        }')

    if [ -n "$tools" ]; then
        json_payload=$(echo "$json_payload" | jq --argjson t "$tools" '. + {tools: $t}')
    fi

    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    local answer=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text')
    printf "\r\033[K" >&2

    if [ "$answer" = "null" ]; then
        echo "❌ API Error:" >&2
        printf '%s' "$response" | jq . 2>/dev/null >&2
        return 1
    fi

    echo "$answer"
}

# --- PUBLIC FUNCTIONS ---

# 1. ASK (Groq 70B)
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

    local result=$(_call_groq "$sys_prompt" "$user_prompt")
    if [ $? -eq 0 ]; then
        if command -v glow &> /dev/null && [ -t 1 ]; then echo "$result" | glow -; else echo "$result"; fi
    fi
}

# 2. REFACTOR (Groq 70B)
refactor() {
    local sys="You are a Clean Code Expert. Rewrite code to be Efficient, Secure, and Readable. Add comments. Output code only."
    local input="${1:-$(cat)}"
    if [ -z "$input" ]; then echo "Usage: refactor < file"; return 1; fi
    _call_groq "$sys" "$input"
}

# 3. MORPH (Groq 70B)
morph() {
    local target="$1"
    local input="${2:-$(cat)}"
    if [ -z "$target" ]; then echo "Usage: morph 'format' < input"; return 1; fi
    _call_groq "Convert input to $target. Output raw data only." "$input"
}

# 4. AUDIT (Groq 70B)
audit() {
    local input="${1:-$(cat)}"
    _call_groq "Scan for security risks. Output checklist: ❌ CRITICAL, ⚠️ WARNING, ✅ SAFE." "$input"
}

# 5. WHY (Groq 70B)
why() {
    local input="${1:-$(cat)}"
    _call_groq "Explain error root cause in 1 sentence. Provide 3 fix steps." "$input"
}

# 6. SUMMARIZE (Groq 70B)
summarize() {
    local input="${1:-$(cat)}"
    _call_groq "Summarize into 3-5 bullet points. Capture key technical details." "$input"
}

# 7. GCMT (Gemini 2.5 - High Context)
gcmt() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then echo "❌ Not a git repo."; return 1; fi
    if git diff --cached --quiet; then echo "⚠️  No staged changes."; return 1; fi

    local branch=$(git branch --show-current)
    local diff_content=$(git diff --cached --no-color --no-ext-diff | head -c 100000)

    local sys="You are a Release Manager. Write a Semantic Git Commit Message. Format: <type>(<scope>): <subject>. Rules: Imperative mood. Output ONLY the raw string."
    local user_prompt="Current Branch: $branch\n\nCode Changes:\n$diff_content"
    
    local msg=$(_call_gemini "$sys" "$user_prompt")
    msg=$(echo "$msg" | sed 's/^```.*//g' | sed 's/```$//g' | awk '{$1=$1};1')
    
    if [ -z "$msg" ]; then return 1; fi
    echo -e "\n\033[1;32m$msg\033[0m"
    echo -n "🚀 Commit? [y/n/e]: "
    read -r choice
    case "$choice" in
        y|Y) git commit -m "$msg" ;;
        e|E) git commit -m "$msg" -e ;;
        *) echo "❌ Aborted." ;;
    esac
}

# 8. GURU (Gemini 2.5 - Context Aware)
guru() {
    local context_files=""
    local user_prompt=""
    local context_tree=""
    
    if command -v lsd &> /dev/null; then
        context_tree=$(lsd --tree --depth 2 --group-directories-first --ignore-glob .git --ignore-glob node_modules)
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

    local result=$(_call_gemini "$sys" "$user_prompt" '[{ google_search: {} }]')
    if command -v glow &> /dev/null; then echo "$result" | glow -; else echo "$result"; fi
}

# 9. VISION (Gemini 2.5 - Multimodal)
vision() {
    local api_key=$(_get_key "GEMINI_API_KEY" "GEMINI_API_KEY")
    if [ -z "$api_key" ]; then echo "❌ Error: GEMINI_API_KEY missing."; return 1; fi

    local file_path="$1"
    local user_prompt="${2:-Analyze this file in detail.}"
    if [ ! -f "$file_path" ]; then echo "❌ File not found."; return 1; fi

    echo "👀 Analyzing..." >&2
    local mime_type=$(file --mime-type -b "$file_path")
    local b64_data
    if [[ "$OSTYPE" == "darwin"* ]]; then b64_data=$(base64 -i "$file_path"); else b64_data=$(base64 -w0 "$file_path"); fi

    local json_payload=$(jq -n \
        --arg text "$user_prompt" \
        --arg data "$b64_data" \
        --arg mime "$mime_type" \
        '{ contents: [{ parts: [{text: $text}, {inline_data: {mime_type: $mime, data: $data}}] }] }')

    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    local answer=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text')
    printf "\r\033[K" >&2
    
    if command -v glow &> /dev/null; then echo "$answer" | glow -; else echo "$answer"; fi
}

# 10. RESEARCH (Gemini 2.5 - Web Search)
research() {
    local prompt="$*"
    if [ -z "$prompt" ]; then echo "Usage: research 'topic'"; return 1; fi
    local result=$(_call_gemini "You are a Research Assistant. Use Google Search." "$prompt" '[{ google_search: {} }]')
    if command -v glow &> /dev/null; then echo "$result" | glow -; else echo "$result"; fi
}
