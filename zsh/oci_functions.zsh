# ==========================================
#  TAMATAR CLOUD INFRASTRUCTURE (Fedora)
# ==========================================

# --- 0. GLOBAL CONFIGURATION ---
# Cache Namespace/Region to speed up terminal launch
# (Run 'oci os ns get' once manually if this slows down shell startup)
[ -z "$OCI_NS" ] && export OCI_NS=$(oci os ns get --query data --raw-output 2>/dev/null)
export OCI_REGION="ap-mumbai-1"

# Load secrets
if [ -f ~/.oci/.secrets.sh ]; then
    source ~/.oci/.secrets.sh
fi

# Helper: Copy to Clipboard (Wayland/X11/Mac safe)
_copy_to_clip() {
  if command -v wl-copy &> /dev/null; then echo -n "$1" | wl-copy
  elif command -v xclip &> /dev/null; then echo -n "$1" | xclip -selection clipboard
  elif command -v pbcopy &> /dev/null; then echo -n "$1" | pbcopy
  fi
}

# ------------------------------------------
# 1. BASKET (Private Storage - S3)
# ------------------------------------------
# Uses Rclone for transfer, OCI CLI for generating temporary links (PARs)
basket() {
  local CMD=$1
  local REMOTE="oracle:basket"

  case "$CMD" in
    ls)
      # List files with sizes (Fast)
      echo "📂 Listing Basket..."
      rclone lsl "$REMOTE"
      ;;
    
    push)
      # Upload file/folder
      if [ -z "$2" ]; then echo "Usage: basket push <file>"; return 1; fi
      echo "⬆️  Uploading '$2'..."
      rclone copy "$2" "$REMOTE/" -P
      ;;
    
    pull)
      # Download (Interactive Mode with FZF)
      local TARGET="$2"
      
      # If no file specified, use FZF to find one in the bucket
      if [ -z "$TARGET" ]; then
        echo "🔍 Searching Basket..."
        TARGET=$(rclone lsf "$REMOTE" -R --files-only | fzf --height 40% --layout=reverse --border)
        [ -z "$TARGET" ] && return # Cancelled
      fi

      echo "⬇️  Downloading '$TARGET'..."
      rclone copy "$REMOTE/$TARGET" . -P
      ;;
    
    rm)
      # Delete file
      if [ -z "$2" ]; then echo "Usage: basket rm <file>"; return 1; fi
      rclone delete "$REMOTE/$2" -P
      echo "🗑️  Deleted '$2'"
      ;;
    
    link)
      # Generate Pre-Authenticated Request (Temp Link)
      if [ -z "$2" ]; then echo "Usage: basket link <file>"; return 1; fi
      
      echo "🔗 Generating 24h Magic Link for '$2'..."
      
      # Calculate Expiry (GNU/Linux compatible)
      local EXPIRY=$(date -u -d '+1 day' +%Y-%m-%dT%H:%M:%SZ)
      
      # Create PAR via OCI CLI
      local PAR_PATH=$(oci os preauth-request create \
         --namespace $OCI_NS --bucket-name basket \
         --name "share_$(date +%s)" \
         --object-name "$2" \
         --access-type ObjectRead \
         --time-expires "$EXPIRY" \
         --query "data.\"access-uri\"" --raw-output)
      
      local FULL_URL="https://objectstorage.${OCI_REGION}.oraclecloud.com${PAR_PATH}"
      _copy_to_clip "$FULL_URL"
      echo "✅ Copied: $FULL_URL"
      ;;
      
    *)
      echo "Usage: basket {ls | push <file> | pull [file] | rm <file> | link <file>}"
      ;;
  esac
}

# ------------------------------------------
# 2. SITE (The "Tamatar Vercel" Deployer)
# ------------------------------------------
site() {
  local CMD=$1
  local REMOTE="oracle:website"
  
  case "$CMD" in
    deploy)
      local SRC="$2"
      local PROJECT="$3" # Project Name (Subdomain)

      if [ -z "$SRC" ] || [ -z "$PROJECT" ]; then 
        echo "Usage: site deploy <local_folder> <project_name>"
        echo "Ex:    site deploy ./dist todo-app"
        return 1
      fi
      
      echo "🚀 Deploying '$PROJECT' from '$SRC'..."
      
      # Sync to: website/project_name/
      rclone sync "$SRC" "$REMOTE/$PROJECT/" \
        --progress \
        --transfers 16 \
        --checksum \
        --delete-excluded
      
      # Construct the SSL-safe URL
      local URL="https://${PROJECT}-site.tamatar.dev"
      
      # Copy to clipboard
      _copy_to_clip "$URL"
      
      echo "✅ Deployed Successfully!"
      echo "🌍 Live at: $URL (Copied to clipboard)"
      ;;
      
    ls)
      echo "📂 Active Projects:"
      rclone lsf "$REMOTE" --dirs-only
      ;;
      
    rm)
      local PROJECT="$2"
      if [ -z "$PROJECT" ]; then echo "Usage: site rm <project_name>"; return 1; fi
      
      echo "🔥 Destroying Project: $PROJECT..."
      rclone purge "$REMOTE/$PROJECT/"
      echo "✅ Project deleted."
      ;;
      
    *)
      echo "Usage: site {deploy <folder> <name> | ls | rm <name>}"
      ;;
  esac
}

# ------------------------------------------
# 3. DROP (Quick Public Share)
# ------------------------------------------
# The "Imgur" killer. Uploads to public bucket, copies pretty URL.
drop() {
  local FILE="$1"
  local REMOTE="oracle:dropzone"
  local DOMAIN="drop.tamatar.dev" # Your Cloudflare Domain

  if [ ! -f "$FILE" ]; then echo "❌ File not found."; return 1; fi

  echo "🍅 Dropping '$FILE'..."
  
  # Upload
  rclone copy "$FILE" "$REMOTE/" -P

  if [ $? -eq 0 ]; then
    # URL Encode filename for web safety
    local FILENAME=$(basename "$FILE")
    local ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FILENAME'))")
    
    local URL="https://${DOMAIN}/${ENCODED}"
    _copy_to_clip "$URL"
    echo "✅ Link Copied: $URL"
  else
    echo "❌ Upload failed."
  fi
}

# ------------------------------------------
# 4. BUCKET MANAGER (Generic S3 Interface)
# ------------------------------------------
buckets() {
  local CMD=$1
  local TARGET=$2
  local REMOTE="oracle"  # Your Rclone remote name

  # Helper: List all buckets if no arguments
  if [ -z "$CMD" ]; then
    echo "📦 Active Buckets:"
    # 'rclone lsd' lists "directories" at the root, which are Buckets in OCI
    rclone lsd "$REMOTE:" | awk '{print $5}' | sed 's/^/  - /'
    return
  fi

  case "$CMD" in
    # 1. LIST: buckets ls <bucket_name> [path]
    ls)
      if [ -z "$TARGET" ]; then
        # List all buckets (Detailed)
        rclone lsd "$REMOTE:"
      else
        # List contents of a specific bucket/folder
        echo "📂 Listing '$TARGET'..."
        rclone lsf "$REMOTE:$TARGET"
      fi
      ;;

    # 2. MAKE: buckets mk <bucket_name>
    mk)
      if [ -z "$TARGET" ]; then echo "Usage: buckets mk <new_bucket_name>"; return 1; fi
      echo "Yz Creating bucket '$TARGET'..."
      
      # We use OCI CLI here to ensure it's created in the right compartment & tier
      # (Rclone mkdir works too, but OCI CLI is more precise for 'Standard' tier)
      oci os bucket create \
        --namespace "$OCI_NS" \
        --compartment-id "$COMPARTMENT_ID" \
        --name "$TARGET" \
        --storage-tier Standard \
        --public-access-type NoPublicAccess
      
      echo "✅ Bucket '$TARGET' created."
      ;;

    # 3. REMOVE: buckets rm <bucket_name> OR <bucket/file>
    rm)
      if [ -z "$TARGET" ]; then echo "Usage: buckets rm <bucket_name> or <bucket/path>"; return 1; fi
      
      echo "🔥 WARNING: This will permanently delete '$TARGET'."
      echo -n "Are you sure? [y/N] "
      read -r confirm
      if [[ "$confirm" != "y" ]]; then echo "Aborted."; return 1; fi

      # Check if it's a bucket (root path) or a file/folder
      if [[ "$TARGET" != *"/"* ]]; then
        # It is a bucket -> Use Purge (deletes contents + bucket)
        echo "🗑️  Purging bucket '$TARGET'..."
        rclone purge "$REMOTE:$TARGET"
      else
        # It is a file/folder -> Use Delete
        echo "🗑️  Deleting object '$TARGET'..."
        rclone delete "$REMOTE:$TARGET"
      fi
      ;;

    # 4. COPY: buckets cp <local> <bucket/path> OR <bucket/path> <local>
    cp)
      local SRC=$2
      local DEST=$3
      if [ -z "$SRC" ] || [ -z "$DEST" ]; then 
        echo "Usage: buckets cp <src> <dest>"
        echo "Ex: buckets cp ./file.txt my-bucket/"
        echo "Ex: buckets cp my-bucket/file.txt ."
        return 1
      fi

      # Auto-detect if source is remote or local
      if [[ "$SRC" == *"/"* ]] && [ ! -e "$SRC" ]; then
         # Assume Source is Remote (bucket/file)
         echo "⬇️  Downloading '$SRC' to '$DEST'..."
         rclone copy "$REMOTE:$SRC" "$DEST" -P
      else
         # Assume Source is Local
         echo "⬆️  Uploading '$SRC' to '$DEST'..."
         rclone copy "$SRC" "$REMOTE:$DEST" -P
      fi
      ;;

    # 5. SYNC: buckets sync <local_folder> <bucket_name>
    sync)
      local SRC=$2
      local DEST=$3
      if [ -z "$SRC" ] || [ -z "$DEST" ]; then echo "Usage: buckets sync <local_dir> <bucket_name>"; return 1; fi
      
      echo "🔄 Mirroring '$SRC' -> '$DEST'..."
      rclone sync "$SRC" "$REMOTE:$DEST" -P
      ;;

    *)
      echo "Usage: buckets {ls [name] | mk <name> | rm <name/path> | cp <src> <dest> | sync <src> <dest>}"
      ;;
  esac
}

# ------------------------------------------
# 5. DATABASES (Jam & Pantry)
# ------------------------------------------

# JAM (MySQL Heatwave)
jam() {
  [ -z "$JAM_PASS" ] && echo "⚠️  Env var JAM_PASS is missing" && return 1
  local DB="$1"
  [ -n "$DB" ] && shift
  # Connect via Tailscale IP
  MYSQL_PWD="$JAM_PASS" mysql -h 10.0.1.57 -u admin "$DB" "$@"
}

# PANTRY (Autonomous DB - SQL)
pantry() {
  [ -z "$TNS_ADMIN" ] && export TNS_ADMIN="$HOME/.oci/wallet"
  [ -z "$PANTRY_PASSWORD" ] && [ -f ~/.oci/.secrets ] && source ~/.oci/.secrets

  if [ -n "$1" ]; then
     # One-off command
     sql -L /nolog <<EOF
connect ADMIN/"$PANTRY_PASSWORD"@pantry_high
set sqlformat ansiconsole;
$1
EXIT;
EOF
  else
     # Interactive
     sql ADMIN/"$PANTRY_PASSWORD"@pantry_high
  fi
}


# ------------------------------------------
# 6. PANTRY-SH (Direct Public Access)
# ------------------------------------------
pantrysh() {

  if [ -z "$PANTRY_PASSWORD" ] || [ -z "$PANTRY_HOST" ]; then
    echo "❌ Error: Env vars PANTRY_PASSWORD or PANTRY_HOST not set."
    return 1
  fi

  # 2. Encode Password
  local PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$PANTRY_PASSWORD'))")

  # 3. Connect Direct
  mongosh "mongodb://ADMIN:$PASS@$PANTRY_HOST/ADMIN?authMechanism=PLAIN&authSource=\$external&ssl=true&retryWrites=false&loadBalanced=true" "$@"
}


# ------------------------------------------
# KV STORE (Persistent Dictionary via MySQL)
# ------------------------------------------
kv() {
  local CMD=$1
  local KEY=$2
  local VAL=$3

  _sql_escape() { echo "${1//\'/\'\'}"; }

  case "$CMD" in
    set)
      if [ -z "$KEY" ] || [ -z "$VAL" ]; then echo "Usage: kv set <key> <value>"; return 1; fi
      local SAFE_KEY=$(_sql_escape "$KEY")
      local SAFE_VAL=$(_sql_escape "$VAL")
      
      jam -e "INSERT INTO utils.store (k, v) VALUES ('$SAFE_KEY', '$SAFE_VAL') 
              ON DUPLICATE KEY UPDATE v='$SAFE_VAL';"
      echo "✅ Saved: [$KEY]"
      ;;

    get)
      if [ -z "$KEY" ]; then echo "Usage: kv get <key>"; return 1; fi
      local SAFE_KEY=$(_sql_escape "$KEY")
      
      local RESULT=$(jam -N -B -e "SELECT v FROM utils.store WHERE k='$SAFE_KEY';")
      
      if [ -z "$RESULT" ]; then echo "❌ Key '$KEY' not found."; return 1; fi
      
      if [ -t 1 ]; then echo "$RESULT"; else echo -n "$RESULT"; fi
      ;;

    ls)
      # 1. Fetch Raw Data (Tab Separated)
      local DATA=$(jam -N -B -e "SELECT k, v FROM utils.store ORDER BY k ASC;")
      
      if command -v fzf &> /dev/null; then
        local SELECTED=$(echo "$DATA" | fzf \
            --height 40% \
            --layout=reverse \
            --border \
            --header="Select a Key to Copy Value" \
            --delimiter=$'\t' \
            --with-nth=1 \
            --preview='echo -e {2}' \
            --preview-window='right:50%:wrap')

        if [ -n "$SELECTED" ]; then
          # 3. Extract Value correctly (Handles spaces in value)
          # Cut field 2 onwards based on tab delimiter
          local VALUE=$(echo "$SELECTED" | cut -f2)
          
          # 4. Copy to Clipboard
          _copy_to_clip "$VALUE"
          
          # Visual confirmation
          local KEY_NAME=$(echo "$SELECTED" | cut -f1)
          echo "✅ Copied value for '$KEY_NAME'"
        fi
      else
        # Fallback if no FZF
        echo "$DATA" | column -t -s $'\t'
      fi
      ;;

    rm)
      if [ -z "$KEY" ]; then echo "Usage: kv rm <key>"; return 1; fi
      local SAFE_KEY=$(_sql_escape "$KEY")
      jam -e "DELETE FROM utils.store WHERE k='$SAFE_KEY';"
      echo "🗑️  Deleted [$KEY]"
      ;;

    *)
      echo "Usage: kv {set <k> <v> | get <k> | ls | rm <k>}"
      ;;
  esac
}


# ------------------------------------------
# STOCK (JSON Store via Pantry)
# ------------------------------------------
stock() {
  local CMD=$1
  local FULL_KEY=$2
  local INPUT_VAL=$3

  _mongo_exec() {
    pantrysh --quiet --eval "$1"
  }

  _parse_key() {
    if [[ "$FULL_KEY" == *.* ]]; then
      DOC_ID="${FULL_KEY%%.*}"
      DOC_PATH="${FULL_KEY#*.}"
    else
      DOC_ID="$FULL_KEY"
      DOC_PATH="v"
    fi
  }

  case "$CMD" in
    set)
      if [ -z "$FULL_KEY" ] || [ -z "$INPUT_VAL" ]; then echo "Usage: stock set <key.path> <value|@file>"; return 1; fi
      
      if [[ "$INPUT_VAL" == @* ]]; then
        local FILE_PATH="${INPUT_VAL#@}"
        if [ ! -f "$FILE_PATH" ]; then echo "❌ File '$FILE_PATH' not found."; return 1; fi
        INPUT_VAL=$(cat "$FILE_PATH")
      fi

      _parse_key 
      echo "📦 Stocking '$DOC_PATH' into '$DOC_ID'..." >&2

      local B64_VAL=$(echo -n "$INPUT_VAL" | base64 | tr -d '\n')

      local OUT=$(_mongo_exec "
        var valString = Buffer.from('$B64_VAL', 'base64').toString('utf-8');
        var finalVal = valString;
        try { finalVal = JSON.parse(valString); } catch(e) {}
        
        db.getSiblingDB('utils').stock.updateOne(
          {_id: '$DOC_ID'}, 
          {\$set: { '$DOC_PATH': finalVal, updated: new Date() }}, 
          {upsert: true}
        )
      ")
      
      if [[ "$OUT" == *"acknowledged"* ]]; then
        echo "✅ Stocked: [$FULL_KEY]"
      else
        echo "❌ Failed: $OUT"
        return 1
      fi
      ;;

    get)
      # Auto-Select (Menu)
      if [ -z "$FULL_KEY" ]; then
         stock ls
         return
      fi

      local FILTER="$3"

      # Fetch Data
      if [[ "$FULL_KEY" == *.* ]]; then
        _parse_key
        local JS_QUERY="
          var doc = db.getSiblingDB('utils').stock.findOne({_id: '$DOC_ID'});
          if(!doc) print('NULL');
          else {
            var path = '$DOC_PATH'.split('.');
            var res = doc;
            for(var i=0; i<path.length; i++) {
               if(res === undefined || res === null) break;
               res = res[path[i]];
            }
            if(res === undefined) print('NULL');
            else if(typeof res === 'object') print(JSON.stringify(res));
            else print(res);
          }
        "
      else
        local JS_QUERY="
           var doc = db.getSiblingDB('utils').stock.findOne({_id: '$FULL_KEY'}); 
           if(!doc) print('NULL'); 
           else { delete doc._id; delete doc.updated; print(JSON.stringify(doc)); }
        "
      fi

      local RESULT=$(_mongo_exec "$JS_QUERY")

      if [[ "$RESULT" == *"NULL"* ]] || [[ -z "$RESULT" ]]; then
        echo "❌ '$FULL_KEY' not found." >&2
        return 1
      fi

      # --- INTEGRATION: If no filter, use JQE ---
      if [ -z "$FILTER" ]; then
         # Check if it looks like a JSON object/array
         if [[ "$RESULT" == \{* ]] || [[ "$RESULT" == \[* ]]; then
            echo "$RESULT" | jqe
         else
            echo "$RESULT" # It's just a string/number
         fi
      else
         echo "$RESULT" | jq -r "$FILTER" 2>/dev/null
      fi
      ;;

    ls)
      local DATA=$(_mongo_exec "db.getSiblingDB('utils').stock.find({}).forEach(doc => { 
          var id = doc._id; 
          delete doc._id; delete doc.updated; 
          print(id + '\t' + Buffer.from(JSON.stringify(doc)).toString('base64')) 
      })")
      
      if command -v fzf &> /dev/null; then
        local SELECTED=$(echo "$DATA" | fzf \
            --height 40% --layout=reverse --border --header="Select Stock Item" \
            --delimiter=$'\t' --with-nth=1 \
            --preview='echo {2} | base64 --decode | jq .' \
            --preview-window='right:60%:wrap')

        if [ -n "$SELECTED" ]; then
           local KEY=$(echo "$SELECTED" | cut -f1)
           # If selected, run 'stock get' on it to trigger the JQE explorer
           stock get "$KEY"
        fi
      else
        echo "$DATA" | cut -f1
      fi
      ;;

    rm)
      if [ -z "$FULL_KEY" ]; then echo "Usage: stock rm <key.path>"; return 1; fi
      _parse_key
      if [[ "$DOC_PATH" == "v" ]]; then
         _mongo_exec "db.getSiblingDB('utils').stock.deleteOne({_id: '$DOC_ID'})" > /dev/null
      else
         _mongo_exec "db.getSiblingDB('utils').stock.updateOne({_id: '$DOC_ID'}, {\$unset: {'$DOC_PATH': 1}})" > /dev/null
      fi
      echo "🗑️  Processed [$FULL_KEY]"
      ;;

    *)  
      # If no args, run ls (The Menu)
      if [ -z "$CMD" ]; then
        stock ls
      else
        echo "Usage: stock {set | get | ls | rm}"
      fi
      ;;
  esac
}



# ------------------------------------------
# TASK MANAGER (MySQL Backed)
# ------------------------------------------
task() {
  local CMD=$1
  local ARG="${@:2}" # Capture all remaining args as the task text

  _sql_escape() { echo "${1//\'/\'\'}"; }

  case "$CMD" in
    add)
      if [ -z "$ARG" ]; then echo "Usage: task add <text>"; return 1; fi
      local SAFE_CONTENT=$(_sql_escape "$ARG")
      jam -e "INSERT INTO utils.tasks (content) VALUES ('$SAFE_CONTENT');"
      echo "✅ Task added."
      ;;
    
    ls)
      # Fetch tasks. Use -N (no headers) -B (batch) for clean parsing
      local DATA=$(jam -N -B -e "SET time_zone='+05:30'; SELECT id, content, created_at FROM utils.tasks WHERE status='pending' ORDER BY id DESC;")
      
      if [ -z "$DATA" ]; then
        echo "✨ No pending tasks. Good job!"
        return
      fi

      # Print pretty table
      echo "$DATA" | column -t -s $'\t'
      ;;
    
    done)
      local ID=$2
      
      # Interactive Mode: If no ID provided, use FZF
      if [ -z "$ID" ]; then
        if command -v fzf &> /dev/null; then
           # Get list -> Select -> Extract ID (Column 1)
           local DATA=$(jam -N -B -e "SELECT id, content FROM utils.tasks WHERE status='pending' ORDER BY id DESC;")
           if [ -z "$DATA" ]; then echo "✨ Nothing to do."; return; fi
           
           ID=$(echo "$DATA" | fzf --height 40% --layout=reverse --border --header="Select Task to Complete" | awk '{print $1}')
           [ -z "$ID" ] && return # Cancelled
        else
           echo "Usage: task done <id>"
           return 1
        fi
      fi

      jam -e "UPDATE utils.tasks SET status='done' WHERE id=$ID;"
      echo "🎉 Task $ID completed!"
      ;;
      
    clean)
      echo "🧹 Cleaning up old completed tasks..."
      jam -e "DELETE FROM utils.tasks WHERE status='done';"
      echo "✅ Trash emptied."
      ;;
      
    *)
      # Default to listing if no command, or help
      if [ -z "$CMD" ]; then
        task ls
      else
        echo "Usage: task {add <text> | ls | done [id] | clean}"
      fi
      ;;
  esac
}


# ------------------------------------------
# VAULT (Secret Injection via MySQL)
# ------------------------------------------
vault() {
  local CMD=$1
  local KEY=$2
  local VAL=$3

  _sql_escape() { echo "${1//\'/\'\'}"; }

  # Helper: Interactive Key Selector
  _vault_pick() {
    if command -v fzf &> /dev/null; then
       jam -N -B -e "SELECT CONCAT(k, ' (', category, ')') FROM utils.secrets ORDER BY category, k;" \
       | fzf --height 40% --layout=reverse --border --header="Select Secret" \
       | awk '{print $1}'
    fi
  }

  case "$CMD" in
    # 1. ADD: vault add KEY VAL [category]
    add)
      if [ -z "$KEY" ] || [ -z "$VAL" ]; then echo "Usage: vault add <KEY> <VALUE> [category]"; return 1; fi
      local CAT="${4:-general}"
      
      local SAFE_KEY=$(_sql_escape "$KEY")
      local SAFE_VAL=$(_sql_escape "$VAL")
      local SAFE_CAT=$(_sql_escape "$CAT")
      
      jam -e "INSERT INTO utils.secrets (k, v, category) VALUES ('$SAFE_KEY', '$SAFE_VAL', '$SAFE_CAT') 
              ON DUPLICATE KEY UPDATE v='$SAFE_VAL', category='$SAFE_CAT';"
      echo "🔒 Secret '$KEY' secured in '$CAT'."
      ;;

    # 2. LOAD: vault load [KEY] (Single)
    load)
      if [ -z "$KEY" ]; then KEY=$(_vault_pick); fi
      if [ -z "$KEY" ]; then echo "Usage: vault load <KEY>"; return 1; fi

      local SAFE_KEY=$(_sql_escape "$KEY")
      local SECRET=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='$SAFE_KEY';")
      
      if [ -n "$SECRET" ]; then
        export "$KEY"="$SECRET"
        echo "🔓 Exported $KEY to current session."
      else
        echo "❌ Secret '$KEY' not found."
      fi
      ;;

    # 3. ENV: vault env [CATEGORY] (Bulk Load)
    env)
      local CAT=$KEY
      
      # Interactive: Pick category if none provided
      if [ -z "$CAT" ] && command -v fzf &> /dev/null; then
        local RAW_MYSQL="MYSQL_PWD='$JAM_PASS' mysql -h 10.0.1.57 -u admin"
        local PREVIEW_CMD="printf \"SELECT k FROM utils.secrets WHERE category='%s' ORDER BY k\" {} | $RAW_MYSQL -N -B | head -n 20"

         CAT=$(jam -N -B -e "SELECT DISTINCT category FROM utils.secrets;" | fzf \
            --height 40% \
            --layout=reverse \
            --border \
            --header="Select Context (Preview shows keys)" \
            --preview "$PREVIEW_CMD" \
            --preview-window="right:40%:wrap" \
         )
      fi

      if [ -z "$CAT" ]; then echo "Usage: vault env <CATEGORY>"; return 1; fi

      local SAFE_CAT=$(_sql_escape "$CAT")
      local COUNT=0
      
      echo "🔓 Loading '$CAT' environment..."
      
      # Loop through results and export them
      while IFS=$'\t' read -r k v; do
         if [ -n "$k" ]; then
           export "$k"="$v"
           echo "   + $k"
           ((COUNT++))
         fi
      done < <(jam -N -B -e "SELECT k, v FROM utils.secrets WHERE category='$SAFE_CAT';")
      
      if [ "$COUNT" -eq 0 ]; then
         echo "⚠️  No secrets found for category '$CAT'."
      else
         echo "✅ Loaded $COUNT secrets."
      fi
      ;;

    # 4. PEEK: vault peek [KEY]
    peek)
      if [ -z "$KEY" ]; then KEY=$(_vault_pick); fi
      if [ -z "$KEY" ]; then echo "Usage: vault peek <KEY>"; return 1; fi

      local SAFE_KEY=$(_sql_escape "$KEY")
      local SECRET=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='$SAFE_KEY';")
      
      if [ -n "$SECRET" ]; then
        _copy_to_clip "$SECRET"  # Ensure you have this helper defined elsewhere or use xclip/pbcopy directly
        echo "📋 Secret '$KEY' copied to clipboard (hidden)."
      else
        echo "❌ Secret '$KEY' not found."
      fi
      ;;

    # 5. LS: List keys (Updated to accept category)
    ls)
      # If $KEY ($2) is provided, we filter by it. Otherwise list all.
      local FILTER_CAT=$KEY
      local QUERY="SELECT category, k, updated_at FROM utils.secrets"
      
      if [ -n "$FILTER_CAT" ]; then
        local SAFE_CAT=$(_sql_escape "$FILTER_CAT")
        QUERY="$QUERY WHERE category='$SAFE_CAT'"
      fi
      
      QUERY="$QUERY ORDER BY category, k;"
      
      jam -N -B -e "SET time_zone='+05:30'; $QUERY" | column -t -s $'\t'
      ;;

    # 6. RM: vault rm [KEY]
    rm)
      if [ -z "$KEY" ]; then KEY=$(_vault_pick); fi
      if [ -z "$KEY" ]; then echo "Usage: vault rm <KEY>"; return 1; fi

      local SAFE_KEY=$(_sql_escape "$KEY")
      jam -e "DELETE FROM utils.secrets WHERE k='$SAFE_KEY';"
      echo "🗑️  Deleted $KEY"
      ;;
    # 7. PRUNE: vault prune [CATEGORY] (Delete entire category)
    prune)
      local CAT=$KEY # $2 is passed as KEY at top of function
      
      # 1. Interactive: Pick category if none provided
      if [ -z "$CAT" ] && command -v fzf &> /dev/null; then
         CAT=$(jam -N -B -e "SELECT DISTINCT category FROM utils.secrets;" | fzf \
            --height 40% \
            --layout=reverse \
            --border \
            --header="🔥 SELECT CATEGORY TO DELETE (ALL KEYS) 🔥" \
         )
      fi

      if [ -z "$CAT" ]; then echo "Usage: vault prune <CATEGORY>"; return 1; fi

      local SAFE_CAT=$(_sql_escape "$CAT")
      
      # 2. Safety Check: Count how many secrets exist
      local COUNT=$(jam -N -B -e "SELECT COUNT(*) FROM utils.secrets WHERE category='$SAFE_CAT';")
      
      if [ "$COUNT" -eq 0 ]; then
         echo "⚠️  Category '$CAT' is already empty or does not exist."
         return
      fi

      # 3. Confirmation Prompt
      echo "🔥 DANGER: You are about to delete the entire '$CAT' category."
      echo -n "❓ This will destroy $COUNT secrets. Are you sure? [y/N] "
      read -r CONFIRM
      
      if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
         jam -e "DELETE FROM utils.secrets WHERE category='$SAFE_CAT';"
         echo "🗑️  Nuked $COUNT secrets from '$CAT'."
      else
         echo "❌ Aborted."
      fi
      ;;
    *)
      echo "Usage: vault {add | load | env | peek | ls | rm}"
      ;;
  esac
}
