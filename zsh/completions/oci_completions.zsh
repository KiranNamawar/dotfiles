# ==========================================
#  OCI & DATABASE COMPLETIONS
# ==========================================

# --- BASKET ---
_basket_comp() {
    _arguments "1:subcommand:(ls push pull rm link)" \
               "2:file:_files" \
               "3:duration:(1h 1d 1w)"
}

# --- SITE ---
_site_comp() {
    _arguments "1:subcommand:(deploy ls rm)" \
               "2:directory:_files -/" \
               "3:project_name"
}

# --- DROP ---
_drop_comp() {
    _arguments "1:subcommand:(ls rm)" \
               "2:file:_files"
}

# --- BUCKETS ---
_buckets_comp() {
    _arguments "1:subcommand:(ls mk rm cp sync nuke)" \
               "2:target" \
               "3:destination"
}

# --- JAM & PANTRY ---
_jam_comp() { _arguments "1:database" "2:sql_query" }
_pantry_comp() { _arguments "1:sql_query" }

# --- KV ---
_kv_comp() {
    _arguments "1:subcommand:(set get rm ls)" \
               "2:key" \
               "3:value"
}

# --- STOCK ---
_stock_comp() {
    _arguments "1:subcommand:(set get ls rm)" \
               "2:key_path" \
               "3:value_or_file:_files"
}

# --- TASK ---
_task_comp() {
    _arguments "1:subcommand:(add ls done clean)" \
               "2:content_or_id"
}

# --- VAULT ---
_vault_comp() {
    _arguments "1:subcommand:(add load env ls peek rm prune)" \
               "2:key" \
               "3:category"
}

# --- MARK ---
_mark_comp() {
    _arguments "1:subcommand:(add ls rm init)" \
               "2:url_or_id"
}

# --- CLIP ---
_clip_comp() {
    _arguments "1:subcommand:(copy paste ls mem clean)" \
               "2:content"
}

# --- TEMPDB ---
_tempdb_comp() {
    _arguments "1:engine:(mysql pg ls drop clean)" \
               "--ttl:duration" \
               "--note:description" \
               "--name:db_name"
}

# --- POST ---
_post_comp() {
    _arguments "1:subject" "2:body" "3:to_email"
}

# --- DAILY ---
_daily_comp() {
    _arguments "1:subcommand:(add ls check do note up rm all)" \
               "2:arg2" "3:arg3" "4:arg4"
}

# --- NOTES ---
_notes_comp() {
    _arguments "1:subcommand:(up push backup down pull restore status check open index memorize)"
}

# --- REGISTER COMPLETIONS ---
compdef _basket_comp basket
compdef _site_comp site
compdef _drop_comp drop
compdef _buckets_comp buckets
compdef _jam_comp jam
compdef _pantry_comp pantry pantrysh
compdef _kv_comp kv
compdef _stock_comp stock
compdef _task_comp task
compdef _vault_comp vault
compdef _mark_comp mark
compdef _clip_comp clip
compdef _tempdb_comp tempdb
compdef _post_comp post
compdef _daily_comp daily
compdef _notes_comp notes
