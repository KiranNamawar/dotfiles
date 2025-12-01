# ==========================================
#  AZURE (SKY) COMPLETIONS
# ==========================================

# --- SILO ---
_silo_comp() {
    _arguments "1:subcommand:(backup restore)" "2:database"
}

# --- TRUNK ---
_trunk_comp() {
    _arguments "1:subcommand:(mount unmount ls)"
}

# --- REM ---
_rem_comp() {
    _arguments "1:description" "2:command"
}

# --- OOPS ---
_oops_comp() {
    _arguments "1:error_msg" "2:fix_command"
}

# --- READ-PDF ---
_read_pdf_comp() {
    _arguments "1:pdf_file:_files -g '*.pdf'"
}

# --- SAY/HEY ---
_say_comp() {
    _arguments "1:text_or_command"
}

# --- HIVE/LEDGER ---
_hive_comp() { _arguments "1:mongo_command" }
_ledger_comp() { _arguments "1:sql_query" }

# --- LOAD-ENV ---
_load_env_comp() { _arguments }

# --- REGISTER COMPLETIONS ---
compdef _silo_comp silo
compdef _trunk_comp trunk
compdef _rem_comp rem
compdef _oops_comp oops

compdef _say_comp say hey
compdef _hive_comp hive
compdef _ledger_comp ledger
compdef _load_env_comp load-env
