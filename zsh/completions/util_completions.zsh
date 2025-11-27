# ==========================================
#  LOCAL UTILITY COMPLETIONS
# ==========================================

# --- 1. UTILITIES ON DB (Vault, KV, Task) ---

_vault_comp() {
    local -a cmds=('add:Secure secret' 'load:Export secret' 'env:Load category' 'peek:Copy silent' 'ls:List' 'rm:Delete' 'prune:Delete category')
    _arguments -C '1: :->cmds' '*:: :->args'
    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                add) _arguments '1:Key' '2:Value' '3:Category' ;;
                env|prune) _message "Category" ;;
                *) _message "Key" ;;
            esac ;;
    esac
}

_kv_comp() {
    local -a cmds=('set:Save' 'get:Retrieve' 'ls:List' 'rm:Delete')
    _arguments -C '1: :->cmds' '*:: :->args'
    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                set) _arguments '1:Key' '2:Value' ;;
                *) _message "Key" ;;
            esac ;;
    esac
}

_task_comp() {
    local -a cmds=('add:New' 'ls:List' 'done:Complete' 'clean:Purge')
    _arguments -C '1: :->cmds' '*:: :->args'
    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                done) _message "Task ID" ;;
                add) _message "Description" ;;
            esac ;;
    esac
}

# --- STOCK ---
_stock_comp() {
    local -a cmds
    cmds=('set:Store JSON/Config' 'get:Retrieve item' 'ls:Explorer' 'rm:Delete')

    _arguments -C '1: :->cmds' '*:: :->args'
    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                set) _arguments '1:Key (app.conf)' '2:Value/File:_files' ;;
                get|rm) _message "Key" ;;
            esac ;;
    esac
}

# --- 2. LOCAL TOOLS (Sys) ---

# JQE (JSON Explorer)
_jqe_comp() {
    _arguments '1:JSON File:_files'
}

# VIEW (Image Viewer)
_view_comp() {
    _arguments \
        '-g[Force GUI Window]' \
        '1:Image File:_files'
}

# FT (Live Grep)
_ft_comp() {
    _arguments \
        '1:Search Query' \
        '2:Path (Optional):_files -/'
}

# FF (Finder), FCD (CD), FOP (Open)
# These take paths/files
_files_comp() {
    _files
}

# Interactive Tools (No Args usually, but prevents error)
_no_args() {
    _message "Interactive Mode"
}

# --- REGISTER ALL ---
compdef _vault_comp vault
compdef _kv_comp kv
compdef _task_comp task
compdef _stock_comp stock
compdef _jqe_comp jqe
compdef _view_comp view
compdef _ft_comp ft
compdef _files_comp ff fcd fop
compdef _no_args proj tkill util
