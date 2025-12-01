# ==========================================
#  TAMATAR OS CORE
# ==========================================

# --- LOAD MODULES ---
[ -f ~/.dotfiles/zsh/oci_functions.zsh ] && source ~/.dotfiles/zsh/oci_functions.zsh
[ -f ~/.dotfiles/zsh/azr_functions.zsh ] && source ~/.dotfiles/zsh/azr_functions.zsh
[ -f ~/.dotfiles/zsh/ai_functions.zsh ]  && source ~/.dotfiles/zsh/ai_functions.zsh
[ -f ~/.dotfiles/zsh/git_functions.zsh ] && source ~/.dotfiles/zsh/git_functions.zsh
[ -f ~/.dotfiles/zsh/local_functions.zsh ] && source ~/.dotfiles/zsh/local_functions.zsh
[ -f ~/.dotfiles/zsh/other_functions.zsh ] && source ~/.dotfiles/zsh/other_functions.zsh

# ------------------------------------------
# HELPER: Dynamic Tool Scanner
# Scans a file for headers: # NAME: cmd, # DESC: desc, # TAGS: tags
# Returns: cmd:desc [tags]:filepath
# ------------------------------------------
_tmt_scan() {
    local file="$1"
    [ ! -f "$file" ] && return
    awk -v f="$file" '
        /^# NAME:/ { name=$3 }
        /^# DESC:/ { desc=substr($0, 8) }
        /^# TAGS:/ { tags=substr($0, 8); if (name) print name ":" desc " [" tags "]:" f; name=""; desc=""; tags="" }
    ' "$file"
}

# ------------------------------------------
# NAME: kit
# DESC: Tamatar Dashboard - Interactive menu for all tools
# USAGE: kit
# TAGS: dashboard, menu, launcher
# ------------------------------------------
kit() {
    # 1. Define Libraries
    local AI_LIB="$HOME/.dotfiles/zsh/ai_functions.zsh"
    local OCI_LIB="$HOME/.dotfiles/zsh/oci_functions.zsh"
    local AZR_LIB="$HOME/.dotfiles/zsh/azr_functions.zsh"
    local UTIL_LIB="$HOME/.dotfiles/zsh/local_functions.zsh"
    local GIT_LIB="$HOME/.dotfiles/zsh/git_functions.zsh"
    local OTHER_LIB="$HOME/.dotfiles/zsh/other_functions.zsh"

    # 2. Build Dynamic Menu
    local tools=()
    
    # Scan all libraries
    # We use a while loop to read the output of _tmt_scan into the array
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$AI_LIB")
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$OCI_LIB")
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$AZR_LIB")
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$GIT_LIB")
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$UTIL_LIB")
    while IFS= read -r line; do tools+=("$line"); done < <(_tmt_scan "$OTHER_LIB")
    
    # Add Manual Entry (Self)
    tools+=("tamatar:Manual [help, guide]:$UTIL_LIB")

    # 3. Run FZF with 'awk' Paragraph Preview
    # We pass the library path as the 3rd column in the list (cmd:desc:path)
    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
        --height=70% \
        --layout=reverse \
        --border \
        --exact \
        --tiebreak=begin \
        --header="🍅 Tamatar Dashboard" \
        --prompt="Select Tool > " \
        --delimiter="  +" \
        --with-nth=1,2 \
        --preview="awk -v func_name={1} '/^#|^[[:space:]]*$/ { buf = buf \$0 \"\\n\"; next } \$0 ~ \"^\" func_name \"\\\\(\\\\)\" { print buf \$0; in_func = 1; buf = \"\"; next } in_func { print \$0; if (\$0 ~ /^}/) exit } { buf = \"\" }' {3} | bat -l zsh --color=always --style=numbers" \
        --preview-window="right:60%:wrap" \
        | awk '{print $1}')

    # 4. Push to Buffer (ZSH specific)
    if [[ -n "$selected" ]]; then
        print -z "$selected "
    fi
}

# ------------------------------------------
# NAME: sys
# DESC: System Status - Check connectivity and cloud status
# USAGE: sys
# TAGS: status, check, ping
# ------------------------------------------
sys() {
    echo ""
    echo -e "🍅 \033[1;31mTAMATAR STATUS\033[0m"
    echo "--------------------------------"

    # OCI Check
    printf "☁️  OCI (Router)... "
    if ping -c 1 -W 1 router &>/dev/null; then
        echo -e "\033[1;32mONLINE\033[0m"
        if [ -n "$JAM_PASS" ]; then
            local tasks=$(timeout 1s mysql -h 10.0.1.57 -u admin "-p$JAM_PASS" -N -B -e "SELECT COUNT(*) FROM utils.tasks WHERE status='pending';" 2>/dev/null)
            [[ -n "$tasks" && "$tasks" -gt 0 ]] && echo "   └── 📝 Tasks: $tasks"
        fi
    else
        echo -e "\033[1;31mOFFLINE\033[0m"
    fi

    # Azure Check
    printf "🔷 Azure (Station)... "
    if ping -c 1 -W 1 station &>/dev/null; then
        echo -e "\033[1;32mONLINE\033[0m"
    else
        echo -e "\033[1;31mOFFLINE\033[0m"
    fi

    echo ""
}

# ------------------------------------------
# NAME: tamatar
# DESC: Tamatar OS Manual - List available commands
# USAGE: tamatar
# TAGS: help, manual, guide
# ------------------------------------------
tamatar() {
    echo -e "\n🍅 \033[1;31mTAMATAR OS v2.0\033[0m"
    echo -e "\033[1;33m[ BRAIN ]\033[0m"
    echo "  mark add <url>       :: Save & summarize bookmark (OCI + Vector)"
    echo "  memory <cmd>         :: Manage AI Memory (AstraDB)"
    echo "  rask <question>      :: AI Chat with access to your memory"
    echo "  rem <desc> <cmd>     :: Remember a shell command"

    echo "  load-env             :: Index project .memory file"

    echo -e "\n\033[1;33m[ CLOUD ]\033[0m"
    echo "  basket ls/push/pull  :: Private Storage (OCI)"
    echo "  drop <file>          :: Public File Share (OCI + Edge)"
    echo "  site deploy <dir>    :: Static Web Hosting (OCI + Edge)"
    echo "  buckets ls/mk/nuke   :: Infrastructure Manager"
    echo "  tunnel <port>        :: Public Localhost (demo.tamatar.dev)"

    echo -e "\n\033[1;33m[ DATA ]\033[0m"
    echo "  jam <sql>            :: MySQL Database (OCI)"
    echo "  silo <sql>           :: Postgres Database (Azure)"
    echo "  stock set/get/ls     :: NoSQL JSON Store (OCI)"
    echo "  kv set/get           :: Key-Value Store"
    echo "  vault add/peek       :: Secret Manager"
    echo "  clip copy/paste      :: Cloud Clipboard"

    echo -e "\n\033[1;33m[ LOCAL ]\033[0m"
    echo "  notes up/down        :: Sync Obsidian to Cloud"
    echo "  kit                  :: Interactive Dashboard"
    echo "  sys                  :: System Status Check"
    echo ""
}

# ------------------------------------------
# NAME: tmt
# DESC: Tamatar CLI - Master wrapper for all commands
# USAGE: tmt <category> <command> [args]
# TAGS: cli, wrapper, master
# ------------------------------------------
tmt() {
    local SUB=$1
    local CMD=$2
    shift 2 2>/dev/null # Shift args so $@ contains the rest

    # --- HELPER: Auto-Source ---
    # (Now handled at top level, but kept for safety)
    _tmt_ensure() {
        :
    }
    _tmt_ensure

    case "$SUB" in
            # 1. BRAIN LAYER (AI & Memory)
        brain|ai)
            case "$CMD" in
                ask|think|agent) "$CMD" "$@" ;;
                vision|research) "$CMD" "$@" ;;
                guru|rask)       "$CMD" "$@" ;;
                digest|refactor) "$CMD" "$@" ;;
                morph|audit|why) "$CMD" "$@" ;;
                summarize|rx)    "$CMD" "$@" ;;
                pick|explain)    "$CMD" "$@" ;;
                jsql|jask)       "$CMD" "$@" ;;
                jqg|jqa|search)  "$CMD" "$@" ;;
                memory)          "$CMD" "$@" ;;
                save|mark)       mark "$@" ;;
                mem|recall)      memory "$@" ;;
                cmd|rem)         rem "$@" ;;
                clip)            clip "$@" ;;
                *)               echo "Usage: tmt brain {ask|think|agent|vision|...}" ;;
            esac
            ;;

            # 2. CLOUD LAYER (OCI)
        cloud|store)
            case "$CMD" in
                basket|site|drop) "$CMD" "$@" ;;
                buckets|jam)      "$CMD" "$@" ;;
                pantry|pantrysh)  "$CMD" "$@" ;;
                kv|stock|task)    "$CMD" "$@" ;;
                vault|mark|clip)  "$CMD" "$@" ;;
                tempdb|post)      "$CMD" "$@" ;;
                daily|notes)      "$CMD" "$@" ;;
                s3)               basket "$@" ;;
                nas)              trunk "$@" ;;
                infra)            buckets "$@" ;;
                sync)             notes "$@" ;;
                *)                echo "Usage: tmt cloud {basket|site|drop|jam|...}" ;;
            esac
            ;;

            # 3. SKY LAYER (Azure)
        sky|azr)
            case "$CMD" in
                silo|hive)       "$CMD" "$@" ;;
                trunk|ledger)    "$CMD" "$@" ;;
                rem)             "$CMD" "$@" ;;
                recall)          memory "$@" ;;
                oops)   "$CMD" "$@" ;;
                load-env|say)    "$CMD" "$@" ;;
                hey)             "$CMD" "$@" ;;
                *)               echo "Usage: tmt sky {silo|hive|trunk|rem|...}" ;;
            esac
            ;;

            # 4. GIT LAYER
        git)
            case "$CMD" in
                gcmt|gmem)       "$CMD" "$@" ;;
                gask|gwhy)       "$CMD" "$@" ;;
                glog|gdev)       "$CMD" "$@" ;;
                *)               echo "Usage: tmt git {gcmt|gmem|gask|gwhy|glog|gdev}" ;;
            esac
            ;;

            # 5. LOCAL LAYER
        local)
            case "$CMD" in
                util|fop|tkill)  "$CMD" "$@" ;;
                view|ft|ff)      "$CMD" "$@" ;;
                *)               echo "Usage: tmt local {util|fop|tkill|view|ft|ff}" ;;
            esac
            ;;

            # 6. HELP MENU
        help|--help|-h)
            echo "🍅 TAMATAR CONTROL PLANE"
            echo "------------------------"
            echo "  tmt brain  :: AI, Memory, Reasoning"
            echo "  tmt cloud  :: OCI, Storage, DBs"
            echo "  tmt sky    :: Azure, Vector, Voice"
            echo "  tmt git    :: Semantic Git Tools"
            echo "  tmt local  :: System Utilities"
            echo ""
            echo "💡 Magic Mode: tmt 'your question' -> asks AI"
            ;;

            # 7. MAGIC FALLBACK (The AI Router)
        *)
            # If the user typed "tmt how to fix wifi", $SUB is "how"
            # We reconstruct the full sentence and ask 'rask'
            if [ -n "$SUB" ]; then
                local QUERY="$SUB $CMD $*"
                echo "🤖 Routing to Brain: '$QUERY'"
                rask "$QUERY"
            else
                # Default to Dashboard if no args
                kit
            fi
            ;;
    esac
}
