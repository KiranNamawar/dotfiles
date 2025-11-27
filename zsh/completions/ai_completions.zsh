# ==========================================
#  AI TOOLS COMPLETIONS
# ==========================================

# --- 1. PIPE/FILE TOOLS (refactor, audit, why, etc) ---
_ai_pipe_comp() {
    _arguments '1:Input File (or pipe):_files'
}

# --- 2. MORPH ---
_morph_comp() {
    _arguments \
        '1:Target Format (json, csv, xml, table)' \
        '2:Input File (Optional):_files'
}

# --- 3. GURU (Architect) ---
_guru_comp() {
    _arguments \
        '*-f[Context File]:File:_files' \
        '1:Question/Instruction'
}

# --- 4. VISION ---
_vision_comp() {
    _arguments \
        '1:Image File:_files' \
        '2:Prompt (Optional)'
}

# --- 5. PICK (Extractor) ---
_pick_comp() {
    _arguments \
        '1:Entity to extract (e.g. "IP addresses")' \
        '2:Input File (Optional):_files'
}

# --- 6. SIMPLE STRING ARGS ---
_research_comp() { _arguments '1:Search Query' }
_rx_comp()       { _arguments '1:Regex Description' }
_search_comp()   { _arguments '1:File Description' }
_explain_comp()  { _arguments '1:Code Snippet or Command' }

# --- 7. SQL & JQ TOOLS ---
_jsql_comp() {
    _arguments \
        '1:Query Description' \
        '-d[Database Name]:Database:_databases'
}
_jqg_comp() { _arguments '1:Filter Description' }

# Helper for Databases
_databases() {
    local -a dbs
    dbs=(${(f)"$(jam -N -B -e 'SHOW DATABASES;' 2>/dev/null)"})
    _describe 'databases' dbs
}

# --- 8. ASK ---
_ask_comp() {
    _arguments '-s[System Prompt]:System Prompt' '1:Question'
}

# --- REGISTER ALL ---
compdef _ai_pipe_comp refactor audit why summarize
compdef _morph_comp morph
compdef _guru_comp guru
compdef _vision_comp vision
compdef _pick_comp pick
compdef _research_comp research
compdef _rx_comp rx
compdef _search_comp search
compdef _explain_comp explain
compdef _jsql_comp jsql jask
compdef _jqg_comp jqg jqa
compdef _ask_comp ask
compdef _git_commit gcmt  # Reuse git completion logic if available, else standard
