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

# ------------------------------------------
# EMBEDDING HELPER (Text -> Vector)
# ------------------------------------------
_get_embedding() {
    local text="$1"
    local api_key=$(_get_key "GEMINI_API_KEY")
    
    # 1. Construct JSON
    # Truncate text to ~2000 chars to stay safe within limits
    local clean_text=$(echo "$text" | tr -d '\n"' | head -c 8000)
    
    local payload=$(jq -n \
        --arg t "$clean_text" \
        '{ model: "models/text-embedding-004", content: { parts: [{ text: $t }] } }')

    # 2. Call API
    local response=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "$payload")

    # 3. Parse Vector
    # Output must be formatted for Postgres: [0.1,0.2,-0.1,...]
    local vector=$(echo "$response" | jq -r '.embedding.values | @json')
    
    if [[ "$vector" == "null" || -z "$vector" ]]; then
        return 1
    fi
    echo "$vector"
}

# ------------------------------------------
# OpenRouter API Caller (File-Based Reliability)
# ------------------------------------------
_call_openrouter() {
    local sys_prompt="$1"
    local user_input="$2"
    local model="$3"
    
    local api_key=$(_get_key "OPENROUTER_API_KEY")
    if [ -z "$api_key" ]; then echo "❌ Error: OPENROUTER_API_KEY missing."; return 1; fi

    echo -n "🧠 Deep Thinking ($model)..." >&2

    # Use temp files to prevent pipe buffer issues with large responses
    local req_file=$(mktemp /tmp/tmt_req_XXXX.json)
    local res_file=$(mktemp /tmp/tmt_res_XXXX.json)

    jq -n \
        --arg sys "$sys_prompt" \
        --arg model "$model" \
        --arg content "$user_input" \
        '{
           model: $model,
           messages: [
             {role: "system", content: $sys},
             {role: "user", content: $content}
           ]
         }' > "$req_file"

    # Capture HTTP code to detect server errors
    # -o writes output to file, preventing stdout leakage
    local http_code=$(curl -s -w "%{http_code}" -o "$res_file" -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: https://tamatar.dev" \
        -H "X-Title: Tamatar CLI" \
        -d "@$req_file")

    rm "$req_file"

    if [[ "$http_code" -ne 200 ]]; then
        echo -e "\n❌ API Error ($http_code):" >&2
        cat "$res_file" >&2
        rm "$res_file"
        return 1
    fi

    # Python Parser for safety
    local answer=$(python3 -c "
import sys, json
try:
    with open('$res_file', 'r') as f:
        data = json.load(f)
    if 'error' in data:
        print('API_ERROR: ' + str(data['error']))
    else:
        print(data['choices'][0]['message']['content'])
except Exception:
    print('JSON_PARSE_ERROR')
")
    
    rm "$res_file"

    if [[ "$answer" == "JSON_PARSE_ERROR" ]]; then
        echo -e "\n❌ Failed to parse JSON response." >&2
        return 1
    elif [[ "$answer" == API_ERROR* ]]; then
        echo -e "\n❌ $answer" >&2
        return 1
    fi

    echo "$answer"
}

# ==========================================
# 21. MEMORY (AstraDB Vector Client)
# ==========================================
# Purpose: Massive long-term AI memory (80GB Free).
# Usage:   memory                 (Interactive Shell)
#          memory add "text"      (Save)
#          memory search "query"  (Search)
memory() {
    # 1. Load Secrets
    local API=$(_get_key "ASTRA_API_ENDPOINT")
    local TOKEN=$(_get_key "ASTRA_DB_TOKEN")
    
    if [[ -z "$API" || -z "$TOKEN" ]]; then
        echo "❌ Error: Astra credentials missing in Vault."
        return 1
    fi

    # Helper: API Call
    _astra_req() {
        local endpoint="$1"
        local payload="$2"
        curl -s -X POST "$API/api/json/v1/default_keyspace/$endpoint" \
            -H "Token: $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$payload"
    }

    # --- INTERACTIVE MODE ---
    if [[ -z "$1" ]]; then
        echo "🧠 Tamatar Memory Console (AstraDB)"
        echo "   Type 'help' for commands, 'exit' to quit."
        
        local line
        while vared -p "%F{cyan}memory>%f " -c line; do
            if [[ "$line" == "exit" || "$line" == "quit" ]]; then break; fi
            if [[ -n "$line" ]]; then 
                # Use 'eval' to properly split quoted strings in the line
                eval "memory $line"
            fi
            line=""
        done
        echo "👋 Disconnected."
        return
    fi

    local CMD="$1"
    local ARG2="$2"
    local ARG3="$3"

    case "$CMD" in
        init)
            echo "⚙️  Initializing architecture..."
            echo "📚 Creating 'library'..."
            _astra_req "" '{"createCollection": {"name": "library", "options": {"vector": {"dimension": 768, "metric": "cosine"}}}}' | jq -r '.status // .errors'
            echo "🌊 Creating 'stream'..."
            _astra_req "" '{"createCollection": {"name": "stream", "options": {"vector": {"dimension": 768, "metric": "cosine"}}}}' | jq -r '.status // .errors'
            echo "✅ Done."
            ;;

        add|save)
            if [ -z "$ARG2" ]; then echo "Usage: add <text> [source]"; return 1; fi
            local CONTENT="$ARG2"
            local SOURCE="${ARG3:-manual}"
            
            echo -n "🧠 Embedding..."
            local VECTOR=$(_get_embedding "$CONTENT")
            if [[ -z "$VECTOR" ]]; then echo "❌ Embedding failed."; return 1; fi
            
            echo -n " 💾 Storing..."
            local JSON=$(jq -n \
                --arg txt "$CONTENT" \
                --arg src "$SOURCE" \
                --argjson vec "$VECTOR" \
                --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{
                   insertOne: {
                     document: {
                       content: $txt, 
                       "$vector": $vec, 
                       metadata: { source: $src },
                       created_at: $ts
                     }
                   }
                 }')
            
            local OUT=$(_astra_req "library" "$JSON")
            if echo "$OUT" | grep -q "insertedIds"; then echo " ✅ Saved."; else echo " ❌ Failed: $OUT"; fi
            ;;

        ask|search|recall)
            if [ -z "$ARG2" ]; then echo "Usage: search <query>"; return 1; fi
            
            echo -n "🤔 Thinking..." >&2
            local Q_VEC=$(_get_embedding "$ARG2")
            
            echo -e "\r🔍 \033[1;33mResults:\033[0m" >&2
            
            local JSON=$(jq -n \
                --argjson vec "$Q_VEC" \
                '{"find": {"sort": {"$vector": $vec}, "options": {"limit": 5, "includeSimilarity": true}, "projection": {"content": 1, "metadata": 1}}}')
            
            local RESPONSE=$(_astra_req "library" "$JSON")
            
            if echo "$RESPONSE" | grep -q "errors"; then
                echo "❌ API Error:"
                echo "$RESPONSE" | jq .
                return 1
            fi
            
            local COUNT=$(echo "$RESPONSE" | jq -r '.data.documents | length' 2>/dev/null)
            
            if [[ "$COUNT" == "0" || -z "$COUNT" || "$COUNT" == "null" ]]; then
                 echo "📭 No memories found."
                 # Debug: echo "$RESPONSE"
            else
                 echo "$RESPONSE" | jq -r '.data.documents[] | "\n👉 Match: \(.["$similarity"] | . * 100 | floor)%\n   Source: \(.metadata.source)\n   \(.content)"'
            fi
            ;;
            
        help)
            echo "  add <text> [source]   :: Memorize a fact"
            echo "  search <query>        :: Semantic search"
            echo "  init                  :: Setup database"
            echo "  exit                  :: Close console"
            ;;

        *) echo "Usage: memory {init | add | search}";;
    esac
}

# --- public functions ---

# 1. ask
# purpose: general purpose q&a for linux/coding.
# model: llama 3.1 8b (fastest response)
# usage: ask "how do i unzip tar.gz"
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

# ------------------------------------------
# 1. THINK (Reasoning Engine)
# ------------------------------------------
# Purpose: Deep reasoning for complex logic/math.
# Usage:   think "solve the logic puzzle"
think() {
    local input="$*"
    if [ -z "$input" ]; then echo "Usage: think <complex_problem>"; return 1; fi
    
    # TNG DeepSeek Chimera (671B MoE)
    local model="tngtech/deepseek-r1t2-chimera:free"
    
    local sys="You are a Deep Reasoning Engine. 
    Analyze the user's request step-by-step. 
    Output your reasoning process (if applicable) followed by the final solution."
    
    local result=$(_call_openrouter "$sys" "$input" "$model")
    _render_output "$result"
}

# ------------------------------------------
# 2. DIGEST (Massive Context Analyzer)
# ------------------------------------------
# Purpose: Analyze large files/logs using Grok 4.1 (2M context).
# Usage:   cat huge.log | digest "Find errors"
digest() {
    local PROMPT="$1"
    local FILE="$2"
    local CONTENT=""

    if [ ! -t 0 ]; then
        CONTENT=$(cat)
    elif [ -f "$FILE" ]; then
        CONTENT=$(cat "$FILE")
    else
        echo "Usage: cat <data> | digest <instruction>"
        echo "       digest <instruction> <filename>"
        return 1
    fi

    if [ -z "$PROMPT" ]; then echo "❌ Error: Missing instruction."; return 1; fi

    echo -n "🦖 Grokking massive context..." >&2
    local model="x-ai/grok-4.1-fast:free"
    local sys="You are a Data Analyst with a massive context window."
    
    local result=$(_call_openrouter "$sys" "Instruction: $PROMPT\n\nData:\n$CONTENT" "$model")
    _render_output "$result"
}

# ------------------------------------------
# 3. AGENT (Software Engineer)
# ------------------------------------------
# Purpose: Write code/files using Kwaipilot KAT-Coder (256k Context).
# Usage:   agent "Create a Python script" > script.py
agent() {
    local input="$*"
    local context=""
    
    if [ ! -t 0 ]; then
        context="[[ CODE CONTEXT ]]\n$(cat)\n\n"
    fi
    
    if [ -z "$input" ]; then echo "Usage: agent <instruction>"; return 1; fi
    
    local model="kwaipilot/kat-coder-pro:free"
    local sys="You are an Elite Software Engineer. 
    Task: Write high-quality, production-ready code based on the user's instruction.
    Rules: Output ONLY the code. No markdown backticks."
    
    local result=$(_call_openrouter "$sys" "$context$input" "$model")
    echo "$result" | sed 's/^```[a-z]*//g' | sed 's/^```//g'
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


# 8. GURU
# Purpose: Context-aware project architect. Knows your file structure.
# Model: Gemini 2.5 Flash (Context + Search)
# Usage: guru "How do I run this?"
#        guru -f main.rs "Refactor this file"
guru() {
    local context_files=""
    local user_prompt=""
    local context_tree=""

    # 1. Build structure overview
    if command -v lsd &> /dev/null; then
        context_tree=$(lsd --tree --depth 2 --group-directories-first \
            --ignore-glob .git --ignore-glob node_modules --color=never)
    else
        context_tree=$(find . -maxdepth 2 -not -path '*/.*')
    fi

    # 2. Parse args
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                if [ -f "$2" ]; then
                    # Truncate each file to ~8000 chars to stay safe
                    local contents
                    contents=$(command cat "$2" | head -c 8000)
                    context_files+="\n--- FILE: $2 ---\n$contents\n"
                    shift 2
                else
                    echo "⚠️  File not found: $2"
                    shift 2
                fi
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    user_prompt="${args[*]}"

    if [ -z "$user_prompt" ]; then
        echo "Usage: guru [-f file] 'Question...'"
        return 1
    fi

    local sys="You are the Lead Architect.

[[ STRUCTURE ]]
$context_tree

[[ FILES ]]
$context_files

Task: Answer based primarily on the STRUCTURE and FILES above.
If something is unclear, you MAY use Google Search as a secondary source."

    local result=$(_call_gemini "$sys" "$user_prompt" '[{ "google_search": {} }]')
    _render_output "$result"
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
# RASK (Retrieval Augmented Ask)
# ==========================================
# Usage: rask "What is the project X config?"
rask() {
    local QUERY="$1"
    if [ -z "$QUERY" ]; then echo "Usage: rask <question>"; return 1; fi

    # 1. Search Memory (Recall)
    echo -n "🧠 Recalling..." >&2
    
    # We need a raw version of recall search here.
    # We embed the query manually to get the vector.
    local Q_VEC=$(_get_embedding "$QUERY")
    
    # Fetch Top 3 matches from Azure
    local CONTEXT=$(SILO_DB=memory silo "SELECT content FROM items ORDER BY embedding <=> '$Q_VEC' LIMIT 3;" | grep -v "rows)" | grep -v "^--" | tr '\n' ' ')
    
    if [ -z "$CONTEXT" ]; then
        echo " (No memory found)" >&2
        CONTEXT="No relevant memory found."
    else
        echo " (Found context)" >&2
    fi

    # 2. Construct Prompt
    local SYS_PROMPT="You are a Helpful Assistant with access to the user's external memory.
    
    [[ MEMORY CONTEXT ]]
    $CONTEXT
    
    Instructions:
    Answer the user's question using the Memory Context above. 
    If the answer is in the memory, cite it. 
    If not, answer generally but mention you didn't find it in memory."

    # 3. Call AI (Groq is fast)
    local RESULT=$(_call_groq "$SYS_PROMPT" "$QUERY" "llama-3.1-8b-instant")
    _render_output "$RESULT"
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
        "think:Deep Reasoning (DeepSeek)"
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
