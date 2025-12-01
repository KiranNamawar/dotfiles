# ==========================================
#  GIT INTELLIGENCE COMPLETIONS
# ==========================================

# --- GMEM ---
_gmem_comp() {
    _arguments "1:subcommand:(index backfill ls status)" "2:limit"
}

# --- GWHY ---
_gwhy_comp() {
    _arguments "1:target:(HEAD pick)"
}

# --- GDEV/GASK ---
_gdev_comp() {
    _arguments "1:question"
}

# --- GCMT/GLOG ---
_gcmt_comp() { _arguments }

# --- REGISTER COMPLETIONS ---
compdef _gmem_comp gmem
compdef _gwhy_comp gwhy
compdef _gdev_comp gdev gask
compdef _gcmt_comp gcmt glog
