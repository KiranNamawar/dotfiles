# ==========================================
#  AI TOOLS COMPLETIONS
# ==========================================

# --- 1. MEMORY ---
_memory_comp() {
    _arguments "1:subcommand:(add search ls clean init)" "*:args:_files"
}

# --- 2. VISION ---
_vision_comp() {
    _arguments "1:image_file:_files" "2:prompt"
}

# --- 3. FILE/PIPE TOOLS ---
_ai_pipe_comp() {
    _arguments "1:file:_files"
}

# --- 4. SIMPLE STRING ARGS ---
_simple_arg_comp() { _arguments "1:Argument" }

# --- 5. ASK/THINK ---
_ask_comp() {
    _arguments '-s[System Prompt]:System Prompt' '1:Question'
}

# --- 6. DATABASES ---
_databases() {
    local -a dbs
    dbs=(${(f)"$(jam -N -B -e 'SHOW DATABASES;' 2>/dev/null)"})
    _describe 'databases' dbs
}

_jsql_comp() {
    _arguments \
        '1:Query Description' \
        '-d[Database Name]:Database:_databases'
}

# --- REGISTER ALL ---
compdef _ask_comp ask think agent
compdef _ai_pipe_comp digest summarize refactor morph audit explain
compdef _vision_comp vision
compdef _simple_arg_comp research rx pick search rask
compdef _jsql_comp jsql jask
compdef _simple_arg_comp jqg jqa
compdef _memory_comp memory
compdef _ai_pipe_comp guru why
