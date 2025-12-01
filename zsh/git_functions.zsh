# ==========================================
#  TAMATAR GIT INTELLIGENCE LAYER
# ==========================================
# Extra-lazy git on top of:
# - memory  (AstraDB vector DB)
# - Groq / Gemini (AI)
# - Your existing gcmt / rask / ask patterns
# ==========================================

# --- INTERNAL HELPERS ---

# Ensure we are inside a git repo
_gitb_ensure_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Not inside a git repository." >&2
        return 1
    fi
}

# Get repo meta: echo "name root branch"
_gitb_meta() {
    local root name branch
    root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    name=${root:t}
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "$name" "$root" "$branch"
}

# Escape single quotes for SQL
_gitb_sql_esc() {
    echo "${1//\'/\'\'}"
}

# Ensure AI helpers are loaded
_gitb_ensure_ai() {
    if ! command -v _call_groq >/dev/null 2>&1 || ! command -v _get_embedding >/dev/null 2>&1; then
        [ -f ~/.dotfiles/zsh/ai_functions.zsh ] && source ~/.dotfiles/zsh/ai_functions.zsh
    fi
    if ! command -v memory >/dev/null 2>&1; then
        [ -f ~/.dotfiles/zsh/ai_functions.zsh ] && source ~/.dotfiles/zsh/ai_functions.zsh
    fi
}

# Build a compact, embeddable representation of a commit
_gitb_commit_blob() {
    local sha="$1"
    local repo="$2"
    local branch="$3"

    # Basic info
    local header
    header=$(git show --no-color --no-patch --format="Commit: %H%nAuthor: %an <%ae>%nDate:   %ad%n%nSubject: %s%n" "$sha")

    # File+stat summary (short and sweet)
    local files
    files=$(git show --no-color --stat --oneline "$sha" | sed '1d' | head -c 3000)

    cat <<EOF
[${repo}] Commit on branch ${branch}
SHA: ${sha}

${header}
Changes:
${files}
EOF
}

# ------------------------------------------
# NAME: gcmt
# DESC: Semantic Commit - AI writes your commit message
# USAGE: gcmt
# TAGS: git, commit, ai, semantic
# ------------------------------------------
gcmt() {
    _gitb_ensure_repo || return 1
    _gitb_ensure_ai

    if ! git diff --cached --quiet; then
        : # good
    else
        echo "⚠️  No staged changes."
        return 1
    fi

    local meta repo_root repo_name branch diff_content sys user_prompt msg

    meta=($(_gitb_meta)) || return 1
    repo_name="${meta[1]}"
    repo_root="${meta[2]}"
    branch="${meta[3]}"

    diff_content=$(git diff --cached --no-color --no-ext-diff | head -c 100000)

    sys="You are a Semantic Git Commit Writer.
Rules:
1. First line: <type>(<scope>): <subject> (max 50 chars, imperative).
2. Scope should usually be the folder or area touched.
3. Body: Provide a concise but detailed summary. Group changes by component if possible.
4. Do NOT mention AI or tools.
5. Output ONLY the raw commit message, no markdown, no backticks."

    user_prompt="Repo: ${repo_name}
Branch: ${branch}

Files Changed:
$(git diff --cached --name-status)

Diff (staged only):
${diff_content}"

    msg=$(_call_gemini "$sys" "$user_prompt")
    msg=$(echo "$msg" | sed 's/^```.*//g' | sed 's/```$//g' | awk '{$1=$1};1')

    if [ -z "$msg" ]; then
        echo "❌ Empty commit message from AI." >&2
        return 1
    fi

    printf "\r\033[K" >&2
    echo -e "\033[1;32m$msg\033[0m"
    echo -n "🚀 Commit? [y/n/e]: "
    read -r choice

    case "$choice" in
        y|Y)
            if git commit -m "$msg"; then
                # Push into long-term memory: commit summary only
                if command -v memory >/dev/null 2>&1; then
                    local memory="[$repo_name] $msg (Branch: $branch)"
                    ( memory add "$memory" "Git: $repo_name" >/dev/null 2>&1 ) &|
                    echo "🧠 Commit memorized."
                fi
            fi
            ;;
        e|E)
            git commit -m "$msg" -e
            ;;
        *)
            echo "❌ Aborted."
            ;;
    esac
}

# ------------------------------------------
# NAME: gmem
# DESC: Git Memory - Index commits to vector DB
# USAGE: gmem [index|backfill|ls|status]
# TAGS: git, memory, index, vector
# ------------------------------------------
gmem() {
    local sub="$1"; shift 2>/dev/null || true
    _gitb_ensure_repo || return 1
    _gitb_ensure_ai

    local meta repo_name repo_root branch
    meta=($(_gitb_meta)) || return 1
    repo_name="${meta[1]}"
    repo_root="${meta[2]}"
    branch="${meta[3]}"

    case "$sub" in
        index|"")
            local limit="${1:-50}"
            cd "$repo_root" || return 1

            echo "🧠 Indexing last $limit commits for [$repo_name]..."

            git log -n "$limit" --pretty=format:'%H' | while read -r sha; do
                [ -z "$sha" ] && continue

                local blob
                blob=$(_gitb_commit_blob "$sha" "$repo_name" "$branch")

                # Use memory to embed + store (AstraDB)
                if command -v memory >/dev/null 2>&1; then
                    memory add "$blob" "Git: $repo_name" >/dev/null 2>&1
                    echo "   ✓ $sha"
                else
                    echo "   ⚠️ memory not available, skipping $sha" >&2
                fi
            done
            ;;

        backfill)
            cd "$repo_root" || return 1
            local total
            total=$(git rev-list --count HEAD)
            echo "⚠️  Backfilling ALL $total commits into memory for [$repo_name]."
            echo -n "Type 'YES' to continue: "
            read -r confirm
            [[ "$confirm" != "YES" ]] && echo "❌ Aborted." && return 1

            echo "🧠 Full history indexing..."
            git rev-list --reverse HEAD | while read -r sha; do
                [ -z "$sha" ] && continue
                local blob
                blob=$(_gitb_commit_blob "$sha" "$repo_name" "$branch")
                if command -v memory >/dev/null 2>&1; then
                    memory add "$blob" "Git: $repo_name" >/dev/null 2>&1
                    echo "   ✓ $sha"
                fi
            done
            ;;

        ls)
            cd "$repo_root" || return 1
            # This is just a view into git, not memory, but helpful
            if command -v fzf >/dev/null 2>&1; then
                git log --oneline --graph --decorate --color=always | \
                    fzf --ansi --height=70% --layout=reverse --border \
                        --header="🧠 Git history for [$repo_name]" \
                        --preview='git show --color=always $(echo {} | sed "s/^[^a-f0-9]*\([a-f0-9]\{7,\}\).*/\1/")' \
                        --preview-window='right:60%'
            else
                git log --oneline --graph --decorate
            fi
            ;;

        status)
            cd "$repo_root" || return 1
            local total last10
            total=$(git rev-list --count HEAD)
            echo "📊 Git Memory Status for [$repo_name]:"
            echo "   Total commits in repo: $total"
            echo "   (Memory lives in AstraDB via memory, scoped by source='Git: $repo_name')"
            ;;

        *)
            echo "Usage:"
            echo "  gmem index [N]     # index last N commits (default 50)"
            echo "  gmem backfill      # index full history (danger: many API calls)"
            echo "  gmem ls            # browse git log (fzf)"
            echo "  gmem status        # simple status"
            ;;
    esac
}

# ------------------------------------------
# NAME: gask
# DESC: Git Ask - Chat with your repo history
# USAGE: gask "question"
# TAGS: git, ask, chat, history
# ------------------------------------------
gask() {
    _gitb_ensure_repo || return 1
    _gitb_ensure_ai

    local question="$*"
    if [ -z "$question" ]; then
        echo "Usage: gask \"your question about this repo\"" >&2
        return 1
    fi

    local meta repo_name repo_root branch
    meta=($(_gitb_meta)) || return 1
    repo_name="${meta[1]}"
    repo_root="${meta[2]}"
    branch="${meta[3]}"

    echo "🧠 Consulting git memory for [$repo_name]..." >&2

    # 1. Embed the question
    local Q_VEC
    Q_VEC=$(_get_embedding "$question") || {
        echo "❌ Failed to get embedding." >&2
        return 1
    }

    # 2. Fetch top matches from memory.items
    export SILO_DB="memory"
    local CONTEXT
    CONTEXT=$(silo "SELECT content, source, 1 - (embedding <=> '$Q_VEC') AS score
                    FROM items
                    WHERE source LIKE 'Git: $(_gitb_sql_esc "$repo_name")%'
                    ORDER BY embedding <=> '$Q_VEC'
                    LIMIT 8;" \
              | grep -v "rows)" | grep -v "^--")

    if [ -z "$CONTEXT" ]; then
        CONTEXT="(No git memory found for this repo. Maybe run: gmem index)"
    fi

    local SYS
    SYS="You are the Git Brain for repository '$repo_name'.
You are given snippets of commit history and summaries from this repo.

[[ GIT MEMORY ]]
$CONTEXT

Instructions:
- Answer the user's question using ONLY this context if possible.
- Reference commits by their SHA or subject when helpful.
- If the answer is not clearly in the context, say you are not sure and suggest what to grep or inspect manually."

    local RESULT
    RESULT=$(_call_groq "$SYS" "$question" "llama-3.3-70b-versatile")
    _render_output "$RESULT"
}

# ------------------------------------------
# NAME: gwhy
# DESC: Git Explain - Explain a commit
# USAGE: gwhy [sha|pick]
# TAGS: git, explain, commit, why
# ------------------------------------------
gwhy() {
    _gitb_ensure_repo || return 1
    _gitb_ensure_ai

    local target="$1"
    local sha=""

    if [ -z "$target" ]; then
        sha="HEAD"
    elif [ "$target" = "pick" ]; then
        if ! command -v fzf >/dev/null 2>&1; then
            echo "❌ fzf not installed; cannot pick." >&2
            return 1
        fi
        local line
        line=$(git log --oneline --decorate --color=always | \
               fzf --ansi --height=60% --layout=reverse --border \
                   --header="Select commit to explain" )
        sha=$(echo "$line" | sed 's/^[^a-f0-9]*\([a-f0-9]\{7,\}\).*/\1/')
    else
        sha="$target"
    fi

    local meta repo_name repo_root branch
    meta=($(_gitb_meta)) || return 1
    repo_name="${meta[1]}"
    repo_root="${meta[2]}"
    branch="${meta[3]}"

    cd "$repo_root" || return 1
    local SHOW
    SHOW=$(git show --no-color "$sha" | head -c 60000)

    local SYS
    SYS="You are a senior engineer reviewing a git commit from repo '$repo_name'.

Task:
- Explain what this commit does and why it might have been made.
- Summarize the intent in 3–5 bullet points.
- Highlight any risky changes or things to watch out for.
- If you can infer it, describe the feature or bugfix this is related to."

    local RESULT
    RESULT=$(_call_groq "$SYS" "$SHOW" "llama-3.3-70b-versatile")
    _render_output "$RESULT"
}



# Make sure any old alias doesn't conflict
unalias glog 2>/dev/null

# ------------------------------------------
# NAME: glog
# DESC: Git Log - Interactive log explorer
# USAGE: glog
# TAGS: git, log, explore, fzf
# ------------------------------------------
glog() {
    _gitb_ensure_repo || return 1

    if ! command -v fzf >/dev/null 2>&1; then
        echo "❌ glog requires fzf." >&2
        return 1
    fi

    local meta repo_name repo_root
    meta=($(_gitb_meta)) || return 1
    repo_name="${meta[1]}"
    repo_root="${meta[2]}"

    cd "$repo_root" || return 1

    local selected
    selected=$(git log --oneline --graph --decorate --color=always \
        | fzf --ansi --height=70% --layout=reverse --border \
            --prompt="glog [$repo_name] > " \
            --header="ENTER: show  |  ALT-e: explain (gwhy)" \
            --bind "alt-e:execute-silent(echo {} | sed 's/^[^a-f0-9]*\([a-f0-9]\{7,\}\).*/\1/' | xargs gwhy)+abort" \
            --preview='git show --color=always $(echo {} | sed "s/^[^a-f0-9]*\([a-f0-9]\{7,\}\).*/\1/")' \
            --preview-window='right:60%')

    [ -z "$selected" ] && return 0

    local sha
    sha=$(echo "$selected" | sed 's/^[^a-f0-9]*\([a-f0-9]\{7,\}\).*/\1/')
    git show --color=always "$sha" | ${PAGER:-less -R}
}


# ------------------------------------------
# NAME: gdev
# DESC: Developer Brain - Deep code intelligence
# USAGE: gdev "question"
# TAGS: git, dev, ai, code
# ------------------------------------------
gdev() {
    emulate -L zsh

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ Not inside a git repository."
        return 1
    fi

    if [ -z "$1" ]; then
        echo "Usage: gdev \"Your question\""
        return 1
    fi

    local query="$*"

    local repo_root repo_name
    repo_root=$(git rev-parse --show-toplevel)
    repo_name=$(basename "$repo_root")

    echo "🔍 Getting relevant history from memory..." >&2
    local memory_ctx=""
    if command -v memory >/dev/null 2>&1; then
        # Use the same prefix gmem uses: [repo_name] ...
        memory_ctx=$(memory search "[$repo_name] $query" 2>/dev/null)
    fi

    echo "📜 Scanning git history..." >&2

    # Recent log for general context
    local git_log
    git_log=$(cd "$repo_root" && git log --oneline -n 20)

    # Extract a simple search token from question (first word-ish)
    local token
    token=$(printf '%s\n' "$query" | sed 's/[^A-Za-z0-9_]/ /g' | awk 'NF{print $1; exit}')

    # Related commits (subject/patch) using grep
    local related_commits=""
    if [ -n "$token" ]; then
        related_commits=$(cd "$repo_root" && \
            git log -n 10 --grep="$token" --stat --patch 2>/dev/null | head -c 16000)
    fi

    # Also grab the very latest diff (sometimes relevant even if token fails)
    local git_head_diff
    git_head_diff=$(cd "$repo_root" && git diff HEAD~1..HEAD --stat --patch 2>/dev/null | head -c 8000)

    echo "📦 Collecting file contexts..." >&2

    # Auto-detect file paths from memory + commit text
    local files=()
    files+=("${(@f)$(printf '%s\n%s\n' "$memory_ctx" "$related_commits" \
        | grep -oE '[A-Za-z0-9_./-]+\.(zsh|sh|ts|js|lua|py|go|rs|php|sql)' \
        | sort -u)}")

    # Keep it sane – max 6 files
    (( ${#files[@]} > 6 )) && files=("${files[@]:0:6}")

    local context_files=""
    local f
    for f in "${files[@]}"; do
        # Normalize path relative to repo root
        if [ -f "$repo_root/$f" ]; then
            context_files+="\n--- FILE: $f ---\n"
            context_files+="$(cd "$repo_root" && sed -n '1,260p' "$f")\n"
        fi
    done

    # Project tree (same style as guru)
    local context_tree=""
    if command -v lsd >/dev/null 2>&1; then
        context_tree=$(cd "$repo_root" && \
            lsd --tree --depth 2 --group-directories-first \
                --ignore-glob .git --ignore-glob node_modules --color=never)
    else
        context_tree=$(cd "$repo_root" && find . -maxdepth 2 -not -path '*/.*')
    fi

    # If we have *nothing* extra, just defer to guru
    if [ -z "$memory_ctx" ] && [ -z "$related_commits" ] && [ -z "$git_head_diff" ] && [ -z "$context_files" ]; then
        echo "⚠️  No extra history or files found. Falling back to guru..." >&2
        guru "$query"
        return
    fi

    # Build system prompt (guru-style, but richer)
    local sys="You are the Lead Developer and Architect of the '$repo_name' repository.

Use the repo tree, git history, diffs, semantic memory, and file contents
to answer the user's question as concretely as possible.

Prefer:
- Real details from code and diffs
- Specific function/command names
- Short examples and commands when helpful

If some parts are speculative, clearly say so.

[[ USER QUESTION ]]
$query

[[ PROJECT TREE (truncated) ]]
$context_tree

[[ RECENT GIT LOG ]]
$git_log

[[ RELATED COMMITS (grep '$token') ]]
${related_commits:-'(no specific matching commits found)'}

[[ LATEST DIFF (HEAD~1..HEAD) ]]
${git_head_diff:-'(no recent diff available)'}

[[ SEMANTIC MEMORY (memory hits) ]]
${memory_ctx:-'(no external memory hits – answer from git + code)'}

[[ FILE CONTENTS (truncated) ]]
${context_files:-'(no specific files auto-detected; rely on commits/diffs)'}
"

    # Call Gemini like guru does (with google_search tool enabled)
    local result
    result=$(_call_gemini "$sys" "$query" '[{ "google_search": {} }]')

    _render_output "$result"
}
