
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


# ------------------------------------------
# GROQ AI (The Terminal Brain)
# ------------------------------------------
ask() {
    # 2. Get API Key
    local api_key="$GROQ_API_KEY"
    if [ -z "$api_key" ] && command -v jam &> /dev/null; then
        vault load "GROQ_API_KEY" 2>/dev/null
    fi
    api_key="$GROQ_API_KEY"

    if [ -z "$api_key" ]; then
        echo "❌ Error: GROQ_API_KEY not found in environment or vault."
        echo "   Run: vault add GROQ_API_KEY '...'"
        return 1
    fi

    # 2. Input Handling (Text arg or Pipe)
    local prompt="$*"
    if [ -z "$prompt" ]; then
        if [ ! -t 0 ]; then
            prompt=$(cat) # Read from pipe
        else
            echo "Usage: ask 'how do I unzip tar.gz'"
            echo "       cat error.log | ask 'explain this error'"
            return 1
        fi
    fi

    echo "🤔 Thinking..."

    # 3. Construct JSON (Safely using jq)
    #    We use Llama3-8b because it's insanely fast for CLI tools.
    local json_payload=$(jq -n \
        --arg content "$prompt" \
        --arg model "llama3-8b-8192" \
        '{
           model: $model,
           messages: [
             {role: "system", content: "You are a Linux CLI expert. Provide concise, accurate answers. Output Markdown. Do not be chatty."},
             {role: "user", content: $content}
           ]
         }')

    # 4. API Request
    local response=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    # 5. Parse Output
    local answer=$(echo "$response" | jq -r '.choices[0].message.content')

    # 6. Render (Use Glow if available, else plain text)
    if [ "$answer" = "null" ]; then
        echo "❌ API Error:"
        echo "$response" | jq .
    else
        # Clear the "Thinking..." line
        printf "\r\033[K" 
        
        if command -v glow &> /dev/null; then
            echo "$answer" | glow -
        else
            echo "$answer"
        fi
    fi
}


# ------------------------------------------
# AI GIT COMMIT (gcmt) - Delta Safe Version
# ------------------------------------------
gcmt() {
    # 1. Pre-Flight Checks
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "❌ Not a git repository."
        return 1
    fi

    if git diff --cached --quiet; then
        echo "⚠️  No staged changes found."
        echo "   Use 'git add .' or 'git add <file>' first."
        return 1
    fi

    # 2. Get API Key
    local api_key="$GROQ_API_KEY"
    if [ -z "$api_key" ] && command -v jam &> /dev/null; then
        vault load "GROQ_API_KEY" 2>/dev/null
    fi
    api_key="$GROQ_API_KEY"

    if [ -z "$api_key" ]; then
        echo "❌ Error: GROQ_API_KEY not found."
        return 1
    fi

    # 3. Prepare the Diff (DELTA FIX IS HERE)
    echo "🤔 Reading staged changes..."
    # --no-color: Strips ANSI colors (delta colors)
    # --no-ext-diff: Ignores external diff tools
    # head -c 6000: Prevents sending massive files to API
    local diff_content=$(git diff --cached --no-color --no-ext-diff | head -c 6000)

    # 4. System Prompt
    local system_prompt="You are a senior developer. Write a Semantic Git Commit Message based on the diff.
    Format: <type>(<scope>): <subject>
    Rules:
    - Use Imperative Mood ('Add' not 'Added').
    - Types: feat, fix, docs, style, refactor, test, chore.
    - If breaking, add '!' after type.
    - Output ONLY the raw commit message. No markdown blocks, no quotes."

    # 5. Call Groq API
    echo "🤖 Generating message..."
    local json_payload=$(jq -n \
        --arg content "$diff_content" \
        --arg sys "$system_prompt" \
        --arg model "llama3-8b-8192" \
        '{
           model: $model,
           messages: [
             {role: "system", content: $sys},
             {role: "user", content: $content}
           ],
           temperature: 0.2
         }')

    local response=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    # 6. Parse Result
    local msg=$(echo "$response" | jq -r '.choices[0].message.content')
    
    # Cleanup
    msg=$(echo "$msg" | sed 's/^```.*//g' | sed 's/```$//g' | sed 's/^"//' | sed 's/"$//' | awk '{$1=$1};1')

    if [ -z "$msg" ] || [ "$msg" = "null" ]; then
        echo "❌ Failed to generate message."
        return 1
    fi

    # 7. Interactive Review
    echo ""
    echo "---------------------------------------------------"
    echo -e "\033[1;32m$msg\033[0m"
    echo "---------------------------------------------------"
    echo -n "🚀 Commit with this message? [y/n/e(dit)]: "
    read -r choice

    case "$choice" in
        y|Y) git commit -m "$msg" ;;
        e|E) git commit -m "$msg" -e ;;
        *) echo "❌ Aborted." ;;
    esac
}
