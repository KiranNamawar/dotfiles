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

    # --- ☁️ OCI TOOLS ---
    tools+=(
        "basket:Private Storage (S3):☁️:$OCI_LIB"
        "site:Static Deployer:☁️:$OCI_LIB"
        "drop:Public File Share:☁️:$OCI_LIB"
        "buckets:Infra Manager:☁️:$OCI_LIB"
        "jam:MySQL HeatWave:☁️:$OCI_LIB"
        "pantry:Autonomous DB:☁️:$OCI_LIB"
        "kv:Key-Value Store:☁️:$OCI_LIB"
        "stock:NoSQL Doc Store:☁️:$OCI_LIB"
        "task:Task Manager:☁️:$OCI_LIB"
        "vault:Secret Manager:☁️:$OCI_LIB"
    )

    # --- 🔷 AZURE TOOLS ---
    tools+=(
        "silo:Postgres DB:🔷:$AZR_LIB"
        "hive:Cosmos/Mongo DB:🔷:$AZR_LIB"
        "trunk:100GB Cloud Drive:🔷:$AZR_LIB"
        "ledger:SQL Server (T-SQL):🔷:$AZR_LIB"
        "say:AI Text-to-Speech:🔷:$AZR_LIB"
        "hey:Jarvis Voice Mode:🔷:$AZR_LIB"
    )

    # --- 🧠 AI TOOLS ---
    tools+=(
        "ask:General Q&A (Llama):🧠:$AI_LIB"
        "refactor:Code Optimizer:🧠:$AI_LIB"
        "morph:Data Converter:🧠:$AI_LIB"
        "audit:Security Scanner:🧠:$AI_LIB"
        "why:Debug Explainer:🧠:$AI_LIB"
        "gcmt:Git Committer:🧠:$AI_LIB"
        "guru:Project Architect:🧠:$AI_LIB"
        "vision:Image Analyzer:🧠:$AI_LIB"
        "research:Web Search:🧠:$AI_LIB"
        "rx:Regex Generator:🧠:$AI_LIB"
        "pick:Data Extractor:🧠:$AI_LIB"
        "jsql:SQL Generator:🧠:$AI_LIB"
        "jqg:JQ Generator:🧠:$AI_LIB"
        "search:Smart Find:🧠:$AI_LIB"
    )

    # --- ⚡ LOCAL UTILS ---
    tools+=(
        "ff:Universal Finder:⚡:$UTIL_LIB"
        "ft:Live Grep:⚡:$UTIL_LIB"
        "proj:Tmux Sessionizer:⚡:$UTIL_LIB"
        "fop:Fuzzy Open (Nvim):⚡:$UTIL_LIB"
        "fcd:Fuzzy CD:⚡:$UTIL_LIB"
        "jqe:JSON Explorer:⚡:$UTIL_LIB"
        "view:Image Viewer:⚡:$UTIL_LIB"
        "tkill:Kill Session:⚡:$UTIL_LIB"
    )

    # Run FZF
    # We use --with-nth=1..3 to show Name, Desc, Icon
    # We use {4} (File Path) only for the preview command
    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
            --height=60% \
            --layout=reverse \
            --border \
            --header="🍅 THE KITCHEN" \
            --prompt="🧑‍🍳 Cook > " \
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
    echo -e "🍅 \033[1;31mTAMATAR INFRASTRUCTURE\033[0m"
    echo "--------------------------------"

    # 1. OCI Check
    printf "☁️  OCI (Router)... "
    if ping -c 1 -W 1 router &>/dev/null; then
        echo -e "\033[1;32mONLINE\033[0m"

        # Check Jam Tasks if Router is up
        local tasks=$(timeout 1s mysql -h 10.0.1.57 -u admin "-p$JAM_PASS" -N -B -e "SELECT COUNT(*) FROM utils.tasks WHERE status='pending';" 2>/dev/null)
        if [ -n "$tasks" ]; then
            echo "   └── 📝 Pending Tasks: $tasks"
        fi
    else
        echo -e "\033[1;31mOFFLINE\033[0m"
    fi

    # 2. Azure Check
    printf "🔷 Azure (Station)... "
    if ping -c 1 -W 1 station &>/dev/null; then
        echo -e "\033[1;32mONLINE\033[0m"
    else
        echo -e "\033[1;31mOFFLINE\033[0m"
    fi

    # 3. Local Check
    echo -e "⚡ Local (Void)...  \033[1;32mONLINE\033[0m"
    echo ""
}
