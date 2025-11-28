# ==========================================
#  AZURE (SKY) COMPLETIONS
# ==========================================

# --- SILO (PostgreSQL) ---
_silo_comp() {
    _arguments '1:SQL Query (or interactive)'
}

# --- HIVE (Cosmos DB) ---
_hive_comp() {
    _arguments '1:Mongo Command (e.g. "db.stats()")'
}

# --- LEDGER (SQL Server) ---
_ledger_comp() {
    _arguments '1:T-SQL Query (or interactive)'
}

# --- TRUNK (File Share) ---
_trunk_comp() {
    local -a cmds
    cmds=(
        'mount:Open Trunk (Auto-Enables VPN)' 
        'unmount:Close Trunk (Disables VPN)' 
        'ls:List contents'
    )
    
    _arguments -C '1: :->cmds' '*:: :->args'
    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                mount) _message "Mounts 100GB to ~/trunk" ;;
                *) _message "" ;;
            esac ;;
    esac
}

# --- SAY (Text to Speech) ---
_say_comp() {
    _arguments '1:Text to speak'
}

# --- HEY (Jarvis Mode) ---
_hey_comp() {
    local -a ai_tools
    # These are the "High Value" tools to suggest
    ai_tools=(
        'ask:General Q&A'
        'research:Web Search'
        'summarize:Shorten Text'
        'why:Explain Error'
        'audit:Security Scan'
        'explain:Explain Code'
        'rx:Regex Generator'
        'pick:Extract Data'
    )

    _arguments -C \
        '1: :_alternative "tools:AI Tools:(( ${ai_tools} ))" "questions:Question:()"' \
        '*::Args:->args'

    case $state in
        args) 
            # If the user picked a tool, suggest args for it
            case $line[1] in
                ask|research|rx|explain) _message "Query string" ;;
                summarize|why|audit|pick) _arguments '1:Input File (Optional):_files' ;;
            esac 
            ;;
    esac
}

# --- REGISTER COMPLETIONS ---
compdef _silo_comp silo
compdef _hive_comp hive
compdef _ledger_comp ledger
compdef _trunk_comp trunk
compdef _say_comp say
compdef _hey_comp hey
