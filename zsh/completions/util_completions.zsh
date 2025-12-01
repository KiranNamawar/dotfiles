# ==========================================
#  LOCAL UTILITY COMPLETIONS
# ==========================================

# --- VIEW ---
_view_comp() {
    _arguments "(-g --gui)"{-g,--gui}"[Force GUI viewer]" "1:file:_files"
}

# --- FT ---
_ft_comp() {
    _arguments "1:query" "2:path:_files -/"
}

# --- FF/FOP/UTIL ---
_files_comp() {
    _files
}

_tkill_comp() {
    _arguments
}

# --- JQE ---
_jqe_comp() {
    _arguments "1:json_file:_files -g '*.json'"
}

# --- REGISTER COMPLETIONS ---
compdef _view_comp view
compdef _ft_comp ft
compdef _files_comp ff fop util
compdef _tkill_comp tkill
compdef _jqe_comp jqe
