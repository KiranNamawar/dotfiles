# ==========================================
#  OCI & DATABASE COMPLETIONS
# ==========================================

# --- BASKET ---
_basket_comp() {
    local -a cmds
    cmds=('ls:List files' 'push:Upload file' 'pull:Download file' 'rm:Delete file' 'link:Generate public link')
    
    _arguments -C \
        '1: :->cmds' \
        '*:: :->args'

    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                push) _arguments '1:Local File:_files' ;;
                rm|link|pull) _message "Remote File (e.g. docs/scan.pdf)" ;;
            esac ;;
    esac
}

# --- SITE ---
_site_comp() {
    local -a cmds
    cmds=('deploy:Upload to public web' 'ls:List projects' 'rm:Delete project')

    _arguments -C '1: :->cmds' '*:: :->args'
    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                deploy) _arguments '1:Dist Folder:_files -/' '2:Project Name (Subdomain)' ;;
                rm) _message "Project Name" ;;
            esac ;;
    esac
}

# --- DROP ---
_drop_comp() {
    _arguments '1:File to upload:_files'
}

# --- BUCKETS ---
_buckets_comp() {
    local -a cmds
    cmds=('ls:List' 'mk:Create bucket' 'rm:Delete' 'cp:Copy' 'sync:Mirror' 'nuke:Destroy versions+bucket')

    _arguments -C '1: :->cmds' '*:: :->args'
    case $state in
        cmds) _describe 'command' cmds ;;
        args)
            case $line[1] in
                mk|nuke) _message "Bucket Name" ;;
                cp|sync) _arguments '1:Source:_files' '2:Dest:_files' ;;
                *) _message "Bucket/Path" ;;
            esac ;;
    esac
}

# --- JAM & PANTRY ---
_jam_comp() { _arguments '1:Database/SQL' '*:SQL' }
_pantry_comp() { _arguments '1:SQL Query' }

# --- REGISTER COMPLETIONS ---
compdef _basket_comp basket
compdef _site_comp site
compdef _drop_comp drop
compdef _buckets_comp buckets
compdef _jam_comp jam
compdef _pantry_comp pantry
compdef _pantry_comp pantrysh
