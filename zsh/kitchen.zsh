# ==========================================
#  THE KITCHEN (Unified Launcher)
# ==========================================

# 1. KIT: The Fast Launcher
# Usage: kit
kit() {
    local OCI_LIB="$HOME/.dotfiles/zsh/oci_functions.zsh"
    local AZR_LIB="$HOME/.dotfiles/zsh/azr_functions.zsh"
    local AI_LIB="$HOME/.dotfiles/zsh/ai_functions.zsh"
    local UTIL_LIB="$HOME/.dotfiles/zsh/functions.zsh"

    local -a tools

    # --- 🧠 BRAIN ---
    tools+=(
        "tmt:Master CLI Wrapper:🧠:$UTIL_LIB"
        "mark:Smart Bookmarks:🧠:$OCI_LIB"
        "recall:Semantic Search:🧠:$AZR_LIB"
        "rask:Ask Your Brain:🧠:$AI_LIB"
        "rem:Remember Command:🧠:$AZR_LIB"
        "read-pdf:Index PDF:🧠:$UTIL_LIB"
        "load-env:Index Project:🧠:$UTIL_LIB"
        "gcmt:AI Committer:🧠:$AI_LIB"
    )

    # --- ☁️ CLOUD ---
    tools+=(
        "jam:MySQL Database:☁️:$OCI_LIB"
        "silo:Postgres DB:☁️:$AZR_LIB"
        "basket:Private Storage:☁️:$OCI_LIB"
        "site:Web Hosting:☁️:$OCI_LIB"
        "drop:File Sharing:☁️:$OCI_LIB"
        "stock:NoSQL Store:☁️:$OCI_LIB"
        "vault:Secret Manager:☁️:$OCI_LIB"
        "clip:Cloud Clipboard:☁️:$OCI_LIB"
        "tunnel:Public Localhost:☁️:$UTIL_LIB"
    )

    # --- ⚡ LOCAL ---
    tools+=(
        "notes:Obsidian Sync:⚡:$UTIL_LIB"
        "sys:System Status:⚡:$UTIL_LIB"
        "ff:Smart Find:⚡:$UTIL_LIB"
        "ft:Live Grep:⚡:$UTIL_LIB"
        "proj:Tmux Projects:⚡:$UTIL_LIB"
        "task:Todo Manager:⚡:$OCI_LIB"
    )

    # Run FZF
    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
            --height=60% \
            --layout=reverse \
            --border \
            --header="🍅 TAMATAR OS v2.0" \
            --prompt="🚀 Launch > " \
            --delimiter="  +" \
            --with-nth=1..3 \
            --preview="awk -v func_name={1} 'BEGIN{RS=\"\"} \$0 ~ (\"(^|\\n)\" func_name \"\\\\(\\\\)\") {print}' {4} | bat -l bash --color=always --style=numbers" \
            --preview-window="right:60%:wrap" \
        | awk '{print $1}')

    if [[ -n "$selected" ]]; then
        print -z "$selected "
    fi
}

# 2. SYS: The Status Dashboard
# Usage: sys
# Runs the network checks synchronously so you actually see the results.
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

    # Web Check
    # printf "🌍 Public Web... "
    # if curl -s --head --request GET https://tamatar.dev | grep "200 OK" > /dev/null; then
    #     echo -e "\033[1;32mONLINE\033[0m"
    # else
    #     echo -e "\033[1;33mUNREACHABLE\033[0m"
    # fi
    echo ""
}

# ==========================================
# TAMATAR OS (Manual)
# ==========================================
tamatar() {
    echo -e "\n🍅 \033[1;31mTAMATAR OS v2.0\033[0m"
    echo -e "\033[1;33m[ BRAIN ]\033[0m"
    echo "  mark add <url>       :: Save & summarize bookmark (OCI + Vector)"
    echo "  recall <query>       :: Semantic search (Azure Vector DB)"
    echo "  rask <question>      :: AI Chat with access to your memory"
    echo "  rem <desc> <cmd>     :: Remember a shell command"
    echo "  read-pdf <file>      :: Index PDF content"
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

# ==========================================
# 🍅 TAMATAR CLI (The Master Wrapper)
# ==========================================
# Usage: tmt <category> <command> [args]
# Example: tmt db ls
#          tmt net tunnel 3000
#          tmt brain remember "foo"
#          tmt "how do I fix docker?" (Magic AI Fallback)

tmt() {
    local SUB=$1
    local CMD=$2
    shift 2 2>/dev/null # Shift args so $@ contains the rest

    # --- HELPER: Auto-Source ---
    # Ensures all underlying tools are loaded
    _tmt_ensure() {
        [ -f ~/.dotfiles/zsh/oci_functions.zsh ] && source ~/.dotfiles/zsh/oci_functions.zsh
        [ -f ~/.dotfiles/zsh/azr_functions.zsh ] && source ~/.dotfiles/zsh/azr_functions.zsh
        [ -f ~/.dotfiles/zsh/ai_functions.zsh ]  && source ~/.dotfiles/zsh/ai_functions.zsh
    }
    _tmt_ensure

    case "$SUB" in
            # 1. DATA LAYER (Databases)
        data|db)
            case "$CMD" in
                mysql|jam)   jam "$@" ;;
                pg|silo)     silo "$@" ;;
                mongo|hive)  echo "⚠️ Hive not configured yet." ;; # Placeholder
                json|stock)  stock "$@" ;;
                kv)          kv "$@" ;;
                *)           echo "Usage: tmt data {jam|silo|stock|kv} ..." ;;
            esac
            ;;

            # 2. NETWORK & WEB LAYER
        net|web)
            case "$CMD" in
                tunnel)      tunnel "$@" ;;
                host|site)   site "$@" ;;
                share|drop)  drop "$@" ;;
                ip)          curl -s ifconfig.me; echo "" ;;
                *)           echo "Usage: tmt net {tunnel|site|drop|ip} ..." ;;
            esac
            ;;

            # 3. CLOUD STORAGE LAYER
        cloud|store)
            case "$CMD" in
                s3|basket)   basket "$@" ;;
                nas|trunk)   trunk "$@" ;;
                infra)       buckets "$@" ;;
                sync)        notes "$@" ;;
                *)           echo "Usage: tmt cloud {basket|trunk|infra|sync} ..." ;;
            esac
            ;;

            # 4. BRAIN LAYER (AI & Memory)
        brain|ai)
            case "$CMD" in
                save|mark)   mark "$@" ;;
                mem|recall)  recall "$@" ;;
                ask|rask)    rask "$@" ;;
                cmd|rem)     rem "$@" ;;
                clip)        clip "$@" ;;
                *)           echo "Usage: tmt brain {mark|recall|rask|rem|clip} ..." ;;
            esac
            ;;

            # 5. SYSTEM LAYER (Ops)
        sys|ops)
            case "$CMD" in
                check|status) sys ;;
                menu|kit)     kit ;;
                *)            echo "Usage: tmt sys {status|kit}" ;;
            esac
            ;;

            # 6. HELP MENU
        help|--help|-h)
            echo "🍅 TAMATAR CONTROL PLANE"
            echo "------------------------"
            echo "  tmt data   :: jam, silo, stock, kv"
            echo "  tmt net    :: tunnel, site, drop"
            echo "  tmt cloud  :: basket, trunk, notes"
            echo "  tmt brain  :: recall, mark, ask"
            echo "  tmt sys    :: status, kit"
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
