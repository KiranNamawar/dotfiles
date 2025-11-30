# ==========================================
#  TAMATAR CLOUD INFRASTRUCTURE (OCI Layer)
# ==========================================
# A suite of OCI-powered CLI tools for Fedora.
#
# STORAGE:
# 1. Basket (Private): Personal file storage.
# 2. Site (Public): Static web hosting.
# 3. Drop (Public): Quick file sharing.
#
# DATABASE:
# 4. Jam (MySQL): Internal HeatWave instance.
# 5. Pantry (Oracle SQL): Autonomous Database.
# 6. KV/Stock/Task: Utilities built on top of DBs.
# ==========================================

# --- 0. GLOBAL CONFIG & HELPERS ---

export OCI_NS="bmxlhtckq3io"
export OCI_REGION="ap-mumbai-1"

# Load secrets if present
[ -f ~/.oci/.secrets.sh ] && source ~/.oci/.secrets.sh

# Helper: Copy to Clipboard
_copy_to_clip() {
    if command -v wl-copy &> /dev/null; then echo -n "$1" | wl-copy
    elif command -v xclip &> /dev/null; then echo -n "$1" | xclip -selection clipboard
    elif command -v pbcopy &> /dev/null; then echo -n "$1" | pbcopy
    fi
}

# ------------------------------------------
# 1. BASKET (Private Storage)
# ------------------------------------------
# Purpose: Manages personal files in private OCI Object Storage.
# Usage:   basket ls
#          basket push <file>
#          basket pull <file> (Interactive)
#          basket link <file> (Generates 24h PAR link)
basket() {
    local CMD=$1
    local REMOTE="oracle:basket"

    case "$CMD" in
        ls)
            echo "📂 Listing Basket..."
            # --format "tsp": Time, Size, Path
            # -h: Human readable sizes (e.g., 44 B, 1.2 MB)
            # sed: Trims the seconds slightly for cleaner look if needed, but standard format is okay.
            # awk: Adds colors (Blue for time, Yellow for size, White for file)
            rclone lsf "$REMOTE" --format "tsp" --separator "|" | \
                sort -r | \
                numfmt --to=iec-i --suffix=B --delimiter="|" --field=2 | \
            awk -F "|" '{
         # Clean Time: Split by "." to remove nanoseconds
         split($1, t, ".");

         # Print: Blue Time | Yellow Size | White Name
         printf "\033[1;34m%s\033[0m  \033[1;33m%9s\033[0m  %s\n", t[1], $2, $3
      }'
            ;;
        push)
            local file="$2"
            if [ -z "$file" ]; then echo "Usage: basket push <file>"; return 1; fi

            # Safety Check: Does it exist remotely?
            if [[ -n $(rclone lsf "$REMOTE/$file" 2>/dev/null) ]]; then
                echo -n "⚠️  File exists in basket. Overwrite? [y/N] "
                read -r confirm
                [[ "$confirm" != "y" ]] && echo "❌ Aborted." && return
            fi

            echo "⬆️  Uploading..."
            # Integrate Notify + Time the upload
            time rclone copy "$file" "$REMOTE/" -P && notify -T "arrow_up" --title "Basket" "Uploaded: $file"
            ;;
        pull)
            local TARGET="$2"
            if [ -z "$TARGET" ]; then
                # Improved Preview: Show file size and time
                TARGET=$(rclone lsl "$REMOTE" | fzf --height 40% --layout=reverse --border --header="⬇️  Pull from Basket" | awk '{print $NF}')
                [ -z "$TARGET" ] && return
            fi
            rclone copy "$REMOTE/$TARGET" . -P && notify "✅ Basket: Pulled $TARGET"
            ;;
        rm)
            local file="$2"
            if [ -z "$file" ]; then echo "Usage: basket rm <file>"; return 1; fi

            # 1. Check if file actually exists
            if [[ -z $(rclone lsf "$REMOTE/$file" 2>/dev/null) ]]; then
                echo "❌ Error: File '$file' not found in basket."
                return 1
            fi

            echo "🗑️  Deleting '$file'..."
            rclone delete "$REMOTE/$file" -P && echo "✅ Deleted."
            ;;
        link)
            local file="$2"
            local time="${3:-1d}" # Default to 1 day, but allow '1h', '1w'

            # Convert 1d -> 24h for simple math if needed, but 'date' handles +1 day/week fine.
            # We need to map 1d/1h to 'date' format.
            # Simpler: Just rely on user passing valid date string OR default
            local expiry_str="+1 day"
            if [[ "$time" == *"h"* ]]; then expiry_str="+${time//h/} hour"; fi
            if [[ "$time" == *"d"* ]]; then expiry_str="+${time//d/} day"; fi
            if [[ "$time" == *"w"* ]]; then expiry_str="+${time//w/} week"; fi

            echo "🔗 Generating Link (Expires: $expiry_str)..."
            local EXPIRY=$(date -u -d "$expiry_str" +%Y-%m-%dT%H:%M:%SZ)

            local PAR_PATH=$(oci os preauth-request create --namespace $OCI_NS --bucket-name basket --name "share_$(date +%s)" --object-name "$file" --access-type ObjectRead --time-expires "$EXPIRY" --query "data.\"access-uri\"" --raw-output)

            local FULL_URL="https://objectstorage.${OCI_REGION}.oraclecloud.com${PAR_PATH}"
            _copy_to_clip "$FULL_URL"
            echo "✅ Copied: $FULL_URL"
            ;;
        *) echo "Usage: basket {ls | push <file> | pull | rm | link <file> [1h/1d/1w]}" ;;
    esac
}

# ------------------------------------------
# 2. SITE (Static Deployer)
# ------------------------------------------
# Purpose: Deploys local 'dist' folders to public OCI bucket.
# Usage:   site deploy ./dist my-project
#          site ls
#          site rm my-project
site() {
    local CMD=$1
    local REMOTE="oracle:website"

    # Helper: Shared Purge Logic
    _site_purge() {
        if [ -n "$CF_ZONE_ID" ] && [ -n "$CF_API_TOKEN" ]; then
            echo -n "🧹 Purging Cloudflare Cache... "
            local result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
                    -H "Authorization: Bearer $CF_API_TOKEN" \
                    -H "Content-Type: application/json" \
                -d '{"purge_everything":true}')

            if [ "$(echo "$result" | jq -r '.success')" = "true" ]; then
                echo "✅ Done."
            else
                echo "❌ Failed."
                echo "$result" | jq -r '.errors[0].message' 2>/dev/null
            fi
        else
            echo "⚠️  Secrets missing. Cache NOT purged."
        fi
    }

    case "$CMD" in
        deploy)
            local DIR="$2"
            local PROJ="$3"
            [ -z "$PROJ" ] && echo "Usage: site deploy <dir> <project>" && return 1

            echo "🚀 Deploying '$PROJ'..."
            rclone sync "$DIR" "$REMOTE/$PROJ/" --progress --transfers 16 --checksum --delete-excluded

            local URL="https://${PROJ}-site.tamatar.dev"

            # Trigger Purge
            _site_purge

            _copy_to_clip "$URL"
            echo "🌍 Live at: $URL"
            ;;

        rm)
            local PROJ="$2"
            [ -z "$PROJ" ] && echo "Usage: site rm <project>" && return 1

            echo "🔥 Deleting project '$PROJ'..."
            rclone purge "$REMOTE/$PROJ/"

            # Trigger Purge
            _site_purge

            echo "💀 Project obliterated."
            ;;

        ls) echo "📂 Active Projects:"; rclone lsf "$REMOTE" --dirs-only ;;

        *) echo "Usage: site {deploy | ls | rm}" ;;
    esac
}

# ------------------------------------------
# 3. DROP (Public Share)
# ------------------------------------------
# Purpose: Uploads file to public bucket and returns URL.
# Usage:   drop <file>
drop() {
    local ARG1=$1
    local REMOTE="oracle:dropzone"
    local DOMAIN="drop.tamatar.dev"

    # Helper: Purge Logic (Nuclear Option)
    _drop_purge() {
        if [ -n "$CF_ZONE_ID" ] && [ -n "$CF_API_TOKEN" ]; then
            echo -n "🧹 Purging Cloudflare Cache... "

            # Always use purge_everything. It is the only way to be 100% sure.
            local result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
                    -H "Authorization: Bearer $CF_API_TOKEN" \
                    -H "Content-Type: application/json" \
                -d '{"purge_everything":true}')

            if [ "$(echo "$result" | jq -r '.success')" = "true" ]; then
                echo "✅ Done."
            else
                echo "❌ Failed."
                echo "$result" | jq -r '.errors[0].message' 2>/dev/null
            fi
        else
            echo "⚠️  Secrets missing. Cache NOT purged."
        fi
    }

    case "$ARG1" in
        rm)
            local target="$2"
            if [ -z "$target" ]; then echo "Usage: drop rm <filename>"; return 1; fi

            echo "🔥 Deleting '$target'..."
            # Check existence first
            if [[ -z $(rclone lsf "$REMOTE/$target" 2>/dev/null) ]]; then
                echo "❌ Error: File '$target' not found."
                return 1
            fi

            if rclone delete "$REMOTE/$target" -P; then
                _drop_purge
                echo "💀 Gone."
            fi
            ;;

        ls)
            echo "📂 Active Drops:"
            rclone lsf "$REMOTE" --format "tsp" --separator "|" | \
                sort -r | \
                numfmt --to=iec-i --suffix=B --delimiter="|" --field=2 | \
            awk -F "|" '{
          split($1, t, ".");
          printf "\033[1;34m%s\033[0m  \033[1;33m%9s\033[0m  %s\n", t[1], $2, $3
       }'
            ;;

        *)
            if [ -f "$ARG1" ]; then
                echo "🍅 Dropping '$ARG1'..."
                rclone copy "$ARG1" "$REMOTE/" --header-upload "Content-Disposition: inline" -P

                _drop_purge

                local filename=$(basename "$ARG1")
                local encoded=${filename// /%20}
                local url="https://${DOMAIN}/${encoded}"

                _copy_to_clip "$url"
                echo "✅ Link: $url"
            else
                echo "Usage: drop <file> | drop rm <file> | drop ls"
                return 1
            fi
            ;;
    esac
}

# ------------------------------------------
# 4. BUCKETS (Infra Manager)
# ------------------------------------------
# Purpose: Generic CRUD for all OCI buckets.
# Usage:   buckets mk <name>
#          buckets ls [name]
#          buckets sync <src> <dest>
buckets() {
  local CMD=$1
  local REMOTE="oracle"

  # Ensure Compartment ID is set
  if [ -z "$COMPARTMENT_ID" ]; then
      [ -f ~/.oci/.secrets.sh ] && source ~/.oci/.secrets.sh
  fi
  
  case "$CMD" in
    ls)
      local TARGET="$2"
      if [ -z "$TARGET" ]; then
        echo "📦 Cloud Buckets ($OCI_REGION):"
        local preview_cmd="rclone lsf $REMOTE:{} --format tsp --separator '|' | sort -r | numfmt --to=iec-i --suffix=B --delimiter='|' --field=2 | column -t -s '|'"
        local selected=$(rclone lsd "$REMOTE:" | awk '{print $NF}' | \
            fzf --height 40% --layout=reverse --border --header="Select Bucket" --prompt="🪣 > " --preview="$preview_cmd" --preview-window="right:60%")
        [ -n "$selected" ] && buckets ls "$selected"
      else
        echo "📂 Contents of '$TARGET':"
        rclone lsf "$REMOTE:$TARGET" --format "tsp" --separator "|" | \
        sort -r | \
        numfmt --to=iec-i --suffix=B --delimiter="|" --field=2 | \
        awk -F "|" '{split($1, t, "."); printf "\033[1;34m%s\033[0m  \033[1;33m%9s\033[0m  %s\n", t[1], $2, $3}' | less -F -R -X 
      fi
      ;;

    mk)
      local NAME="$2"
      local ACCESS="${3:-private}" 
      if [ -z "$NAME" ]; then echo "Usage: buckets mk <name> [private/public]"; return 1; fi
      
      if [ -z "$COMPARTMENT_ID" ]; then 
         echo "❌ Error: COMPARTMENT_ID not set."
         return 1
      fi

      local PUBLIC_FLAG="NoPublicAccess"
      [[ "$ACCESS" == "public" ]] && PUBLIC_FLAG="ObjectRead"

      echo "🔨 Creating '$NAME' ($ACCESS)..."
      
      local OUTPUT
      OUTPUT=$(oci os bucket create --namespace "$OCI_NS" --name "$NAME" \
          --compartment-id "$COMPARTMENT_ID" \
          --public-access-type "$PUBLIC_FLAG" \
          --storage-tier Standard 2>&1)

      if [ $? -eq 0 ]; then
          echo "✅ Created."
      else
          echo "❌ Failed."
          # Show the actual error message
          echo "$OUTPUT"
      fi
      ;;

    rm)
      local TARGET="$2"
      [ -z "$TARGET" ] && echo "Usage: buckets rm <name>" && return 1
      if rclone purge "$REMOTE:$TARGET"; then
          echo "🗑️  Deleted."
      else
          echo "❌ Failed to delete (Bucket might be non-empty?)"
      fi
      ;;
    cp)
       local SRC="$2"
       local DEST="$3"
       [ -z "$DEST" ] && echo "Usage: buckets cp <local_path> <bucket_name[/path]>" && return 1
       echo "📋 Copying '$SRC' -> '$REMOTE:$DEST'..."
       rclone copy "$SRC" "$REMOTE:$DEST" -P --transfers 16
       ;;
    sync)
       local SRC="$2"
       local DEST="$3"
       [ -z "$DEST" ] && echo "Usage: buckets sync <local_path> <bucket_name[/path]>" && return 1
       echo "🔄 Syncing '$SRC' -> '$REMOTE:$DEST'..."
       echo "⚠️  Warning: This will DELETE files in '$DEST' that are not in '$SRC'."
       # Rclone sync is destructive to the destination!
       rclone sync "$SRC" "$REMOTE:$DEST" -P --transfers 16 --check-first
       ;;

    nuke)
      local TARGET="$2"
      [ -z "$TARGET" ] && echo "Usage: buckets nuke <name>" && return 1
      echo -e "\n\033[1;31m☢️   WARNING: NUKE DETECTED  ☢️\033[0m"
      echo "Target: '$TARGET'"
      echo -n "Type 'DELETE' to confirm: "
      read -r confirm
      if [[ "$confirm" == "DELETE" ]]; then
        echo "🌪️  Deleting object versions..."
        if ! oci os object bulk-delete-versions --namespace "$OCI_NS" --bucket-name "$TARGET" --force &>/dev/null; then
             echo "❌ Error: Bucket '$TARGET' not found or access denied."
             return 1
        fi
        
        echo "🗑️  Deleting bucket..."
        if oci os bucket delete --namespace "$OCI_NS" --bucket-name "$TARGET" --force &>/dev/null; then
             echo "💥 Obliterated."
        else
             echo "❌ Failed to delete bucket."
        fi
      else
        echo "❌ Aborted."
      fi
      ;;
      
    *) echo "Usage: buckets {ls | mk | rm | sync | nuke}" ;;
  esac
}

# ==========================================
#  OBSIDIAN MANAGER
# ==========================================
notes() {
    local NOTES_PATH="$HOME/Documents/notes"
    local CMD=$1
    local REMOTE="oracle:notes"

    # Safety: Check if local folder exists
    if [ ! -d "$NOTES_PATH" ]; then
        echo "❌ Error: Local path '$NOTES_PATH' does not exist."
        return 1
    fi

    # Config: Ignore the .obsidian folder entirely
    local FLAGS=(--exclude ".obsidian/**")

    case "$CMD" in
        up|push|backup)
            echo "📝 Backing up Notes..."
            # Added $EXCLUDE_FLAGS
            rclone sync "$NOTES_PATH" "$REMOTE" -P --transfers 16 --delete-excluded "${FLAGS[@]}"
            notify -T "memo" "Obsidian Backup Complete"
            ;;

        down|pull|restore)
            echo "⚠️  WARNING: This will OVERWRITE local changes."
            echo -n "Type 'RESTORE' to confirm: "
            read -r confirm
            if [[ "$confirm" == "RESTORE" ]]; then
                echo "📝 Restoring Notes..."
                rclone sync "$REMOTE" "$NOTES_PATH" -P --transfers 16 "${FLAGS[@]}"
                echo "✅ Done."
            else
                echo "❌ Aborted."
            fi
            ;;

        status|check)
            echo "🔍 Checking status"
            
            # Added $EXCLUDE_FLAGS here too so status ignores config files
            local CHANGES=$(rclone check "$NOTES_PATH" "$REMOTE" --combined - "${FLAGS[@]}" 2>/dev/null | grep -v "^=")
            
            if [ -z "$CHANGES" ]; then
                echo "✅ Everything is in sync."
            else
                echo -e "\n\033[1;33mPending Changes:\033[0m"
                echo "$CHANGES" | \
                sed 's/^+ /  🟢 New: /' | \
                sed 's/^- /  🔴 Del: /' | \
                sed 's/^\* /  📝 Mod: /'
            fi
            ;;
            
        open)
            # Silence output and detach process (&|)
            xdg-open "obsidian://open?path=$NOTES_PATH" >/dev/null 2>&1 &|
            ;;

        index|memorize)
            echo "🧠 Indexing Brain to Azure Vector DB..."
            
            # Find all markdown files (limit to last 7 days to be fast, or remove mtime for full scan)
            # You can remove '-mtime -7' to index EVERYTHING (might take a while)
            find "$NOTES_PATH" -name "*.md" -mtime -7 | while read file; do
                local filename=$(basename "$file")
                echo "   Reading: $filename"
                
                # Content: First 1000 chars (Embeddings have limits)
                local content=$(head -c 5000 "$file")
                
                # Send to Recall (Silence output to keep it clean)
                # We use the filename as the 'Source'
                if recall add "Note: $filename. Content: $content" "Obsidian" >/dev/null 2>&1; then
                    echo "   ✅ Indexed: $filename"
                else
                    echo "   ❌ Failed: $filename"
                fi
            done
            ;;
        *) echo "Usage: notes {up | down | status | open}" ;;
    esac
}

# ------------------------------------------
# 5. JAM (MySQL HeatWave)
# ------------------------------------------
# Purpose: Connects to internal MySQL instance via Tailscale.
# Usage:   jam <database> [sql_command]
jam() {
  [ -z "$JAM_PASS" ] && echo "⚠️ Env var JAM_PASS missing" && return 1
  local DB="$1"; [ -n "$DB" ] && shift
  MYSQL_PWD="$JAM_PASS" mysql -h 10.0.1.57 -u admin "$DB" "$@"
}

# ------------------------------------------
# 6. PANTRY (Autonomous DB)
# ------------------------------------------
# Purpose: Connects to Oracle ATP via SQLcl or Mongosh.
# Usage:   pantry       (Interactive SQL)
#          pantry "sql" (One-off)
pantry() {
  [ -z "$TNS_ADMIN" ] && export TNS_ADMIN="$HOME/.oci/wallet"
  [ -z "$PANTRY_PASSWORD" ] && source ~/.oci/.secrets
  if [ -n "$1" ]; then
    sql -L /nolog <<EOF
connect ADMIN/"$PANTRY_PASSWORD"@pantry_high
set sqlformat ansiconsole;
$1
EXIT;
EOF
else
  sql ADMIN/"$PANTRY_PASSWORD"@pantry_high
  fi
}

# ------------------------------------------
# 7. PANTRY-SH (Direct MongoDB Connection)
# ------------------------------------------
# Dependency for 'stock' function
pantrysh() {
        if [ -z "$PANTRY_PASSWORD" ] || [ -z "$PANTRY_HOST" ]; then
            [ -f ~/.oci/.secrets.sh ] && source ~/.oci/.secrets.sh
        fi

        if [ -z "$PANTRY_PASSWORD" ] || [ -z "$PANTRY_HOST" ]; then
            echo "❌ Error: Env vars PANTRY_PASSWORD or PANTRY_HOST not set."
            return 1
        fi

        # URL Encode Password (Python dependency)
        local PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$PANTRY_PASSWORD'))")

        # Connect
        mongosh "mongodb://ADMIN:$PASS@$PANTRY_HOST/ADMIN?authMechanism=PLAIN&authSource=\$external&ssl=true&retryWrites=false&loadBalanced=true" "$@"
    }

# ------------------------------------------
# 8. KV (Key-Value Store)
# ------------------------------------------
# Purpose: Persistent string storage in MySQL.
# Usage:   kv set <key> <val>
#          kv get <key>
#          kv ls  (FZF Menu)
kv() {
    local CMD=$1
    local KEY=$2
    
    # Helper to escape single quotes for SQL
    _esc() { echo "${1//\'/\'\'}"; }

    case "$CMD" in
        set)
            local VAL=$3
            [ -z "$VAL" ] && echo "Usage: kv set <key> <value>" && return 1
            jam -e "INSERT INTO utils.store (k,v) VALUES ('$(_esc "$KEY")','$(_esc "$VAL")') ON DUPLICATE KEY UPDATE v='$(_esc "$VAL")';"
            echo "✅ Set '$KEY'."
            ;;
        get)
            [ -z "$KEY" ] && echo "Usage: kv get <key>" && return 1
            jam -N -B -e "SELECT v FROM utils.store WHERE k='$(_esc "$KEY")';"
            ;;
        rm)
            [ -z "$KEY" ] && echo "Usage: kv rm <key>" && return 1
            jam -e "DELETE FROM utils.store WHERE k='$(_esc "$KEY")';" && echo "🗑️ Deleted."
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
        *) echo "Usage: kv {set | get | ls | rm}" ;;
    esac
}

# ------------------------------------------
# 9. STOCK (JSON Store)
# ------------------------------------------
# Purpose: NoSQL Document storage via Oracle MongoDB API.
# Usage:   stock set <key> <json|@file>
#          stock get <key>
#          stock ls
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
      DOC_PATH=""
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
      
      # Base64 Encode to handle newlines/quotes safely
      local B64_VAL=$(echo -n "$INPUT_VAL" | base64 | tr -d '\n')

      echo "📦 Stocking into '$DOC_ID'..." >&2

      local OUT=$(_mongo_exec "
        var valString = Buffer.from('$B64_VAL', 'base64').toString('utf-8');
        var finalVal = valString;
        try { finalVal = JSON.parse(valString); } catch(e) {
             // Type Inference
             if(finalVal === 'true') finalVal = true;
             else if(finalVal === 'false') finalVal = false;
             else if(!isNaN(finalVal) && finalVal.trim() !== '') finalVal = Number(finalVal);
        }
        
        var query = {_id: '$DOC_ID'};
        
        if ('$DOC_PATH' === '') {
             // FIX: Root Replacement (Flat Structure)
             // We ensure 'finalVal' is an object if we are replacing the root
             if (typeof finalVal !== 'object' || finalVal === null) {
                 finalVal = { 'value': finalVal };
             }
             finalVal.updated = new Date();
             db.getSiblingDB('utils').stock.replaceOne(query, finalVal, {upsert: true});
        } else {
             // FIX: Partial Update at Root
             var setObj = {};
             setObj['$DOC_PATH'] = finalVal;
             setObj.updated = new Date();
             db.getSiblingDB('utils').stock.updateOne(query, {\$set: setObj}, {upsert: true});
        }
      ")
      
      if [[ "$OUT" == *"acknowledged"* ]]; then
        echo "✅ Saved."
      else
        echo "❌ Failed: $OUT"
        return 1
      fi
      ;;

    get)
      [ -z "$FULL_KEY" ] && stock ls && return

      _parse_key
      
      local JS_QUERY="
          var doc = db.getSiblingDB('utils').stock.findOne({_id: '$DOC_ID'});
          if (!doc) {
             print('NULL');
          } else {
             var res = doc;
             var path = '$DOC_PATH';
             if (path) {
                 path.split('.').forEach(p => { 
                    if(res) res = res[p]; 
                 });
             }
             if (res === undefined) print('NULL');
             else if (typeof res === 'object') print(JSON.stringify(res));
             else print(res);
          }
      "

      local RESULT=$(_mongo_exec "$JS_QUERY")

      if [[ "$RESULT" == *"NULL"* ]] || [[ -z "$RESULT" ]]; then
        echo "❌ '$FULL_KEY' not found." >&2
        return 1
      fi

      if [[ "$RESULT" == \{* ]] || [[ "$RESULT" == \[* ]]; then
         echo "$RESULT" | jqe
      else
         echo "$RESULT"
      fi
      ;;

    ls)
      # Uses Base64 to prevent newlines breaking the list
      local DATA=$(_mongo_exec "db.getSiblingDB('utils').stock.find({}).forEach(doc => { 
          var id = doc._id; 
          delete doc._id; delete doc.updated; 
          print(id + '\t' + Buffer.from(JSON.stringify(doc)).toString('base64')) 
      })")
      
      if command -v fzf &> /dev/null; then
        local SELECTED=$(echo "$DATA" | fzf \
            --height 40% --layout=reverse --border --header="📦 Stock Explorer" \
            --delimiter=$'\t' --with-nth=1 \
            --preview='echo {2} | base64 --decode | jq .' \
            --preview-window='right:60%:wrap')

        if [ -n "$SELECTED" ]; then
           local KEY=$(echo "$SELECTED" | cut -f1)
           stock get "$KEY"
        fi
      else
        echo "$DATA" | cut -f1
      fi
      ;;

    rm)
      if [ -z "$FULL_KEY" ]; then echo "Usage: stock rm <key.path>"; return 1; fi
      _parse_key
      
      echo "🗑️  Deleting '$FULL_KEY'..."
      if [ -z "$DOC_PATH" ]; then
         _mongo_exec "db.getSiblingDB('utils').stock.deleteOne({_id: '$DOC_ID'})" > /dev/null
      else
         _mongo_exec "db.getSiblingDB('utils').stock.updateOne({_id: '$DOC_ID'}, {\$unset: {'$DOC_PATH': 1}})" > /dev/null
      fi
      echo "✅ Gone."
      ;;

    *)
      echo "Usage: stock {set | get | ls | rm}"
      ;;
  esac
}

# ------------------------------------------
# 10 . TASK (Todo List)
# ------------------------------------------
# Purpose: Simple CLI task manager backed by MySQL.
# Usage:   task add "Buy Milk"
#          task ls
#          task done <id>
task() {
    local CMD=$1; local ARG="${@:2}"
    case "$CMD" in
        add) 
            [ -z "$ARG" ] && echo "Usage: task add 'Buy Milk'" && return 1
            jam -e "INSERT INTO utils.tasks (content) VALUES ('${ARG//\'/\'\'}');"
            echo "✅ Added task." 
            ;;
        ls)  
            # Pretty print with IDs in bold
            jam -N -B -e "SELECT id, content FROM utils.tasks WHERE status='pending' ORDER BY id DESC;" | \
            awk -F '\t' '{printf "\033[1;36m%s\033[0m  %s\n", $1, $2}'
            ;;
        done) 
            local ID=$2
            if [ -z "$ID" ]; then
              # Interactive FZF selection
              ID=$(jam -N -B -e "SELECT id, content FROM utils.tasks WHERE status='pending';" | \
                    fzf --height 40% --layout=reverse --header="✅ Mark Done" \
                        --delimiter=$'\t' --with-nth=2 \
                        --preview="echo 'Task ID: {1}'" --preview-window="bottom:3:wrap" \
                    | awk '{print $1}')
            fi
            [ -n "$ID" ] && jam -e "UPDATE utils.tasks SET status='done' WHERE id=$ID;" && echo "🎉 Task $ID Complete!" 
            ;;
        clean) 
            jam -e "DELETE FROM utils.tasks WHERE status='done';" 
            echo "🧹 Cleared completed tasks."
            ;;
        *) echo "Usage: task {add | ls | done | clean}" ;;
    esac
}

# ------------------------------------------
# 11. VAULT (Secret Manager)
# ------------------------------------------
# Purpose: Manages API keys and Env vars in MySQL.
# Usage:   vault add <KEY> <VAL>
#          vault load <KEY>
#          vault env <CATEGORY>
vault() {
    local CMD=$1
    local KEY=$2
    
    case "$CMD" in
        add)
            if [ -z "$KEY" ]; then echo "Usage: vault add <KEY> [category]"; return 1; fi
            local CAT="${3:-general}"
            
            echo -n "🔒 Enter Secret for '$KEY': "
            read -s VAL
            echo "" 
            
            jam -e "INSERT INTO utils.secrets (k,v,category) VALUES ('$KEY','$VAL','$CAT') ON DUPLICATE KEY UPDATE v='$VAL';"
            echo "✅ Secret stored."
            ;;
            
        load) 
            local VAL=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='$KEY';")
            if [ -n "$VAL" ]; then
                export "$KEY"="$VAL"
                echo "🔓 Loaded $KEY"
            else
                echo "❌ Key '$KEY' not found."
            fi
            ;;
            
        env) 
            local CAT=$KEY
            [ -z "$CAT" ] && CAT=$(jam -N -B -e "SELECT DISTINCT category FROM utils.secrets;" | fzf --height=20% --layout=reverse --header="Select Category")
            [ -z "$CAT" ] && return
            
            echo "🔓 Loading '$CAT' environment..."
            while IFS=$'\t' read -r k v; do 
                export "$k"="$v"
                echo "   + $k" 
            done < <(jam -N -B -e "SELECT k, v FROM utils.secrets WHERE category='$CAT';") 
            ;;

        peek)
            [ -z "$KEY" ] && echo "Usage: vault peek <KEY>" && return 1
            local VAL=$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='$KEY';")
            if [ -n "$VAL" ]; then echo "$VAL"; else echo "❌ Key '$KEY' not found."; fi
            ;;

        rm)
            [ -z "$KEY" ] && echo "Usage: vault rm <KEY>" && return 1
            jam -e "DELETE FROM utils.secrets WHERE k='$KEY';" && echo "🗑️  Deleted '$KEY'."
            ;;

        prune)
            local CAT=$KEY
            # Interactive selection if no argument
            [ -z "$CAT" ] && CAT=$(jam -N -B -e "SELECT DISTINCT category FROM utils.secrets;" | fzf --height=20% --layout=reverse --header="Select Category to PRUNE")
            [ -z "$CAT" ] && return

            # Count items first
            local COUNT=$(jam -N -B -e "SELECT COUNT(*) FROM utils.secrets WHERE category='$CAT';")
            
            echo -e "\n\033[1;31m☢️   WARNING: PRUNE DETECTED  ☢️\033[0m"
            echo "Category: '$CAT' ($COUNT secrets)"
            echo "Action:   Delete ALL secrets in this category."
            echo -n "Type 'DELETE' to confirm: "
            read -r confirm
            
            if [[ "$confirm" == "DELETE" ]]; then
                jam -e "DELETE FROM utils.secrets WHERE category='$CAT';"
                echo "💥 Pruned category '$CAT'."
            else
                echo "❌ Aborted."
            fi
            ;;
            
        ls) 
            jam -N -B -e "SELECT category, k FROM utils.secrets ORDER BY category;" | \
            awk -F '\t' '{printf "\033[1;34m%-15s\033[0m %s\n", $1, $2}'
            ;;
            
        *) echo "Usage: vault {add | load | env | ls | peek | rm | prune}" ;;
    esac
}

# ------------------------------------------
# 12. MARK (AI Smart Bookmarks) - v1.1 (Zsh Fix)
# ------------------------------------------
# Purpose: Saves URLs to MySQL (Jam) and uses AI to generate summaries/tags.
#
# Usage:   mark add <url>   (Fetch, Analyze, Save)
#          mark ls          (Interactive Search & Open)
#          mark rm <id>     (Delete bookmark)
#
# Dependencies: jam (MySQL), curl, _call_groq (AI Layer)
mark() {
    local CMD=$1
    local ARG=$2

    _mark_init() {
        jam -e "CREATE TABLE IF NOT EXISTS utils.bookmarks (
            id INT AUTO_INCREMENT PRIMARY KEY,
            url TEXT NOT NULL,
            title VARCHAR(255),
            summary TEXT,
            tags VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );" >/dev/null 2>&1
    }

    _html_to_text() {
        # Increased limit to 100k for Gemini (It has a huge context window)
        sed -e 's/<[^>]*>/ /g' | tr -s ' ' | head -c 100000
    }

    case "$CMD" in
        init)
            echo "⚙️  Initializing database table..."
            _mark_init
            echo "✅ Ready."
            ;;

        add)
            if [ -z "$ARG" ]; then echo "Usage: mark add <url>"; return 1; fi
            
            echo "🌐 Fetching content..."
            local HTML=$(curl -sL "$ARG" -H "User-Agent: Mozilla/5.0")
            
            local TITLE=$(echo "$HTML" | grep -oP '(?<=<title>)(.*)(?=</title>)' | head -n 1)
            [ -z "$TITLE" ] && TITLE="$ARG"
            
            local RAW_TEXT=$(echo "$HTML" | _html_to_text)
            
            echo "🧠 Analyzing (Gemini Flash)..."
            local SYS_PROMPT="You are a Bookmark Assistant. Analyze the website text provided.
            Output JSON with two keys:
            1. 'summary': A concise summary (max 3 sentences).
            2. 'tags': A string of 5-7 relevant hashtags (e.g. #linux #dev).
            Do not output markdown code blocks."
            
            local AI_OUT=$(_call_gemini "$SYS_PROMPT" "$RAW_TEXT")
            
            # Clean up potential markdown formatting from AI response
            AI_OUT=$(echo "$AI_OUT" | sed 's/^```json//g' | sed 's/^```//g')
            
            local SUMMARY=$(echo "$AI_OUT" | jq -r '.summary' 2>/dev/null)
            local TAGS=$(echo "$AI_OUT" | jq -r '.tags' 2>/dev/null)
            
            if [[ -z "$SUMMARY" || "$SUMMARY" == "null" ]]; then 
                SUMMARY="AI Analysis Failed"
                TAGS="#link"
            fi

            # --- Inject into Vector Memory ---
            if command -v recall &>/dev/null; then
                echo "🧠 Memorizing..."
                # We execute directly. If it fails, we see the error.
                recall add "Bookmark: $TITLE. $SUMMARY $TAGS" "$ARG"
            fi

            # Clean input for SQL (Remove tabs/newlines from input before saving)
            SUMMARY="${SUMMARY//[$'\t\r\n']/ }"
            TAGS="${TAGS//[$'\t\r\n']/ }"
            TITLE="${TITLE//[$'\t\r\n']/ }"

            jam -e "INSERT INTO utils.bookmarks (url, title, summary, tags) VALUES ('${ARG//\'/\'\'}', '${TITLE//\'/\'\'}', '${SUMMARY//\'/\'\'}', '${TAGS//\'/\'\'}');"
            
            echo "✅ Saved: $TITLE"
            echo "📝 $SUMMARY"
            echo "🏷️  $TAGS"
            ;;

        ls)
            local QUERY="SELECT id, REPLACE(REPLACE(title, '\n', ' '), '\t', ' '), REPLACE(REPLACE(tags, '\n', ' '), '\t', ' '), REPLACE(REPLACE(summary, '\n', ' '), '\t', ' '), url FROM utils.bookmarks ORDER BY id DESC;"
            local DATA=$(jam -N -B -e "$QUERY")
            
            if [ -z "$DATA" ]; then echo "📭 No bookmarks found."; return; fi

            # We pass the full line {} to awk and split by \t explicitly.
            # $3 = Tags, $4 = Summary, $5 = URL
            # We use single quotes for the awk script to prevent shell interference.
            local PREVIEW_CMD="echo {} | awk -F'\t' '{
                print \"\n🏷️  \033[1;36mTags:\033[0m \" \$3;
                print \"\n📝 \033[1;33mSummary:\033[0m\";
                print \$4;
                print \"\n🔗 \033[1;34mURL:\033[0m\n\" \$5
            }'"

            local SELECTED_URL=$(echo "$DATA" | fzf \
                --height 60% --layout=reverse --border --header="🔖 Smart Bookmarks" \
                --delimiter='\t' \
                --with-nth=2,3 \
                --preview "$PREVIEW_CMD" \
                --preview-window="right:65%:wrap" \
                | awk -F'\t' '{print $5}')
            
            if [ -n "$SELECTED_URL" ]; then
                echo "🚀 Opening: $SELECTED_URL"
                xdg-open "$SELECTED_URL" >/dev/null 2>&1
            fi
            ;;

        rm)
            local ID=$ARG
            if [ -z "$ID" ]; then
                  ID=$(jam -N -B -e "SELECT id, title FROM utils.bookmarks;" | \
                      fzf --height 40% --layout=reverse --header="Select to DELETE" \
                          --preview "echo '🗑️  Delete this bookmark?'" \
                          --preview-window="right:40%:wrap" \
                      | awk '{print $1}')
            fi
            
            if [ -n "$ID" ]; then
                jam -e "DELETE FROM utils.bookmarks WHERE id=$ID;"
                echo "🗑️  Deleted bookmark #$ID."
            fi
            ;;

        *) echo "Usage: mark {add <url> | ls | rm <id> | init}" ;;
    esac
}

# ==========================================
# 13. CLIP (Cloud Clipboard)
# ==========================================
# Usage: echo "foo" | clip       (Copy)
#        clip copy "foo"         (Copy arg)
#        clip paste              (Paste latest)
#        clip ls                 (History)
clip() {
    local CMD=$1
    local CONTENT=""

    # 0. INIT (Run once)
    _clip_init() {
        jam -e "CREATE TABLE IF NOT EXISTS utils.clipboard (
            id INT AUTO_INCREMENT PRIMARY KEY,
            content TEXT,
            device VARCHAR(50),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );" >/dev/null 2>&1
    }

    # Helper: Detect Device Name
    local DEVICE_NAME=$(hostname)

    case "$CMD" in
        # COPY: Handles piped input OR arguments
        c|cp|copy)
            _clip_init
            
            # Check if input is piped
            if [ ! -t 0 ]; then
                CONTENT=$(cat)
            else
                CONTENT="${@:2}"
            fi

            if [ -z "$CONTENT" ]; then echo "Usage: echo 'text' | clip OR clip copy 'text'"; return 1; fi

            # Escape for SQL
            local SAFE_CONTENT="${CONTENT//\'/\'\'}"
            
            jam -e "INSERT INTO utils.clipboard (content, device) VALUES ('$SAFE_CONTENT', '$DEVICE_NAME');"
            echo "✂️  Copied to Cloud Clipboard."
            ;;

        # PASTE: Output the most recent item
        p|paste)
            # -N (Skip headers), -B (Batch/Tab separated)
            jam -N -B -e "SELECT content FROM utils.clipboard ORDER BY id DESC LIMIT 1;"
            ;;

        # LIST: Interactive History
        ls|history)
            _clip_init
            local DATA=$(jam -N -B -e "SELECT id, device, content, created_at FROM utils.clipboard ORDER BY id DESC LIMIT 20;")
            
            if [ -z "$DATA" ]; then echo "📭 Clipboard empty."; return; fi

            # FZF: Show Device & Content snippet. Preview full content.
            # Columns: 1=ID, 2=Device, 3=Content, 4=Time
            local SELECTED=$(echo "$DATA" | fzf \
                --height 40% --layout=reverse --border --header="📋 Cloud Clipboard" \
                --delimiter='\t' \
                --with-nth=2,3 \
                --preview "echo {3}" \
                --preview-window="wrap" \
                | cut -f3) # Select the content column directly
            
            if [ -n "$SELECTED" ]; then
                # Copy to local system clipboard if available
                if command -v wl-copy &>/dev/null; then
                    echo -n "$SELECTED" | wl-copy
                    echo "✅ Copied to local clipboard."
                else
                    echo "$SELECTED"
                fi
            fi
            ;;
        
        mem|remember)
            if [ ! -t 0 ]; then CONTENT=$(cat); else CONTENT="${@:2}"; fi
            if [ -z "$CONTENT" ]; then echo "Usage: echo text | clip mem"; return 1; fi
            
            echo "🧠 Sending to Long-Term Memory..."
            recall add "$CONTENT" "Clipboard"
            ;;

        # CLEAR
        clean|clear)
            jam -e "TRUNCATE TABLE utils.clipboard;"
            echo "🧹 Clipboard wiped."
            ;;

        *) 
            # Smart Default: If pipe, copy. If no args, ls.
            if [ ! -t 0 ]; then
                clip copy
            else
                clip ls
            fi
            ;;
    esac
}


# ==========================================
# TEMPDB (Ephemeral Databases)
# ==========================================
# Usage:
#   tempdb mysql [--ttl 4h] [--note "playground"]
#   tempdb pg [--ttl 1d] [--note "testing"]
#   tempdb ls
#   tempdb drop <id|engine:name>
#   tempdb clean
tempdb() {
    local sub=""

    if [[ $# -gt 0 ]]; then
        sub="$1"
        shift
    fi

    # Requires jam (MySQL) & silo (Postgres)
    if ! command -v jam >/dev/null 2>&1; then
        echo "❌ jam (MySQL wrapper) not found." >&2
        return 1
    fi

    # Helper: escape single quotes for SQL
    _tempdb_esc() { echo "${1//\'/\'\'}"; }

    # Ensure metadata table exists
    jam -e "CREATE TABLE IF NOT EXISTS utils.tempdb (
        id INT AUTO_INCREMENT PRIMARY KEY,
        engine ENUM('mysql','pg') NOT NULL,
        name VARCHAR(64) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP NULL,
        notes VARCHAR(255),
        UNIQUE KEY uniq_engine_name (engine, name)
    );" >/dev/null 2>&1

    # Parse TTL like "4h" or "2d" into MySQL INTERVAL
    _tempdb_interval_sql() {
        local ttl="$1"
        local unit="${ttl: -1}"
        local amount="${ttl%$unit}"
        [[ -z "$amount" || "$amount" == "$ttl" ]] && amount=4 unit="h"
        case "$unit" in
            h) echo "INTERVAL $amount HOUR" ;;
            d) echo "INTERVAL $amount DAY" ;;
            *) echo "INTERVAL 4 HOUR" ;;
        esac
    }

    case "$sub" in
        mysql)
            local ttl="4h"
            local note=""
            local name=""

            # Parse flags
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --ttl)  ttl="$2"; shift 2 ;;
                    --note) note="$2"; shift 2 ;;
                    --name) name="$2"; shift 2 ;;
                    *)      shift ;;
                esac
            done

            # Generate a DB name if not provided
            if [ -z "$name" ]; then
                name="tmp_${USER}_$(date +%s)"
            fi
            # Sanitize to valid identifier
            name="${name//[^a-zA-Z0-9_]/_}"

            local interval_sql=$(_tempdb_interval_sql "$ttl")

            echo "🍅 Creating MySQL temp DB '$name'..."
            if ! jam -e "CREATE DATABASE \`$name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; then
                echo "❌ Failed to create database." >&2
                return 1
            fi

            jam -e "INSERT INTO utils.tempdb (engine, name, expires_at, notes)
                    VALUES ('mysql', '$(_tempdb_esc "$name")',
                            DATE_ADD(NOW(), $interval_sql),
                            '$(_tempdb_esc "$note")');" >/dev/null 2>&1

            # Show info
            local info
            info=$(jam -N -B -e "SELECT id, created_at, expires_at FROM utils.tempdb WHERE engine='mysql' AND name='$(_tempdb_esc "$name")';")
            local id created expires
            id=$(echo "$info" | awk -F'\t' 'NR==1{print $1}')
            created=$(echo "$info" | awk -F'\t' 'NR==1{print $2}')
            expires=$(echo "$info" | awk -F'\t' 'NR==1{print $3}')

            echo "✅ MySQL temp DB created:"
            echo "   id     : $id"
            echo "   name   : $name"
            echo "   created: $created"
            echo "   expires: $expires"
            echo ""
            echo "   connect (jam):"
            echo "     jam -e \"USE $name;\""
            echo "   connect (mysql CLI):"
            echo "     mysql -h 10.0.1.57 -u admin -p\$JAM_PASS $name"
            ;;

        pg)
            if ! command -v silo >/dev/null 2>&1; then
                echo "❌ silo (Postgres wrapper) not found." >&2
                return 1
            fi

            local ttl="4h"
            local note=""
            local name=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --ttl)  ttl="$2"; shift 2 ;;
                    --note) note="$2"; shift 2 ;;
                    --name) name="$2"; shift 2 ;;
                    *)      shift ;;
                esac
            done

            if [ -z "$name" ]; then
                name="tmp_${USER}_$(date +%s)"
            fi
            name="${name//[^a-zA-Z0-9_]/_}"

            local interval_sql=$(_tempdb_interval_sql "$ttl")

            echo "🍆 Creating Postgres temp DB '$name'..."
            # We assume silo connects as a superuser to the 'postgres' DB when SILO_DB is unset
            local OLD_SILO_DB="$SILO_DB"
            unset SILO_DB
            if ! silo "CREATE DATABASE \"$name\";" >/dev/null 2>&1; then
                echo "❌ Failed to create Postgres database." >&2
                export SILO_DB="$OLD_SILO_DB"
                return 1
            fi
            export SILO_DB="$OLD_SILO_DB"

            jam -e "INSERT INTO utils.tempdb (engine, name, expires_at, notes)
                    VALUES ('pg', '$(_tempdb_esc "$name")',
                            DATE_ADD(NOW(), $interval_sql),
                            '$(_tempdb_esc "$note")');" >/dev/null 2>&1

            local info
            info=$(jam -N -B -e "SELECT id, created_at, expires_at FROM utils.tempdb WHERE engine='pg' AND name='$(_tempdb_esc "$name")';")
            local id created expires
            id=$(echo "$info" | awk -F'\t' 'NR==1{print $1}')
            created=$(echo "$info" | awk -F'\t' 'NR==1{print $2}')
            expires=$(echo "$info" | awk -F'\t' 'NR==1{print $3}')

            echo "✅ Postgres temp DB created:"
            echo "   id     : $id"
            echo "   name   : $name"
            echo "   created: $created"
            echo "   expires: $expires"
            echo ""
            echo "   connect (silo, one-off):"
            echo "     SILO_DB=$name silo"
            ;;

        ls)
            local rows
            rows=$(jam -N -B -e "SELECT id, engine, name, created_at, expires_at, IF(expires_at < NOW(), 'expired','active') AS status, notes FROM utils.tempdb ORDER BY created_at DESC;")
            if [ -z "$rows" ]; then
                echo "📭 No temp DBs tracked."
                return 0
            fi

            if command -v fzf >/dev/null 2>&1; then
                echo "$rows" | fzf \
                    --height=60% \
                    --layout=reverse \
                    --border \
                    --header="🧪 tempdb list (id | engine | name | created | expires | status | notes)" \
                    --preview 'echo -e "id: {1}\nengine: {2}\nname: {3}\ncreated: {4}\nexpires: {5}\nstatus: {6}\nnotes: {7}"' \
                    --preview-window='right:60%'
            else
                echo "$rows" | column -t -s $'\t'
            fi
            ;;

        drop)
            local target="$1"
            if [ -z "$target" ]; then
                echo "Usage: tempdb drop <id|engine:name>" >&2
                return 1
            fi

            local engine name
            local id=""

            if [[ "$target" =~ ^[0-9]+$ ]]; then
                id="$target"
                # Resolve engine + name by id
                read engine name <<<"$(jam -N -B -e "SELECT engine, name FROM utils.tempdb WHERE id=$id;" | awk -F'\t' 'NR==1{print $1, $2}')"
                if [ -z "$engine" ]; then
                    echo "❌ No tempdb with id=$id" >&2
                    return 1
                fi
            else
                # engine:name
                engine="${target%%:*}"
                name="${target#*:}"
            fi

            if [ -z "$engine" ] || [ -z "$name" ]; then
                echo "❌ Could not resolve engine/name from '$target'." >&2
                return 1
            fi

            echo "🗑️  Dropping $engine database '$name'..."

            case "$engine" in
                mysql)
                    jam -e "DROP DATABASE IF EXISTS \`$name\`;" ;;
                pg)
                    if ! command -v silo >/dev/null 2>&1; then
                        echo "❌ silo (Postgres wrapper) not found." >&2
                        return 1
                    fi

                    echo "   (connecting via silo to drop Postgres DB)..."

                    # Best-effort: kill existing connections (ignore errors)
                    SILO_DB=postgres SILO_FORCE=1 silo \
                        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$name';" \
                        >/dev/null 2>&1 || true

                    # Now actually drop, non-interactively
                    local err rc
                    err=$(SILO_DB=postgres SILO_FORCE=1 silo \
                        "DROP DATABASE IF EXISTS \"$name\";" \
                        2>&1 >/dev/null)
                    rc=$?

                    if [ $rc -ne 0 ]; then
                        echo "❌ Failed to drop Postgres database '$name'."
                        if [ -n "$err" ]; then
                            echo "   Error from silo / Postgres:"
                            echo "   --------------------------------"
                            echo "$err" | sed 's/^/   /'
                            echo "   --------------------------------"
                        fi
                        return 1
                    fi
                    ;;
                *)
                    echo "❌ Unknown engine '$engine'." >&2
                    return 1
                    ;;
            esac

            # Remove metadata
            if [ -n "$id" ]; then
                jam -e "DELETE FROM utils.tempdb WHERE id=$id;" >/dev/null 2>&1
            else
                jam -e "DELETE FROM utils.tempdb WHERE engine='$engine' AND name='$(_tempdb_esc "$name")';" >/dev/null 2>&1
            fi

            echo "✅ Dropped."
            ;;

        clean)
            echo "🧹 Cleaning expired temp DBs..."
            local expired
            expired=$(jam -N -B -e "SELECT id, engine, name FROM utils.tempdb WHERE expires_at IS NOT NULL AND expires_at < NOW();")
            if [ -z "$expired" ]; then
                echo "✅ Nothing to clean."
                return 0
            fi

            echo "$expired" | while IFS=$'\t' read -r id engine name; do
                [ -z "$id" ] && continue
                echo " - $engine:$name (id=$id)"
                tempdb drop "$id"
            done
            ;;

        *)
            echo "Usage:"
            echo "  tempdb mysql [--ttl 4h] [--note 'playground'] [--name custom_name]"
            echo "  tempdb pg    [--ttl 1d] [--note 'testing'] [--name custom_name]"
            echo "  tempdb ls"
            echo "  tempdb drop <id|engine:name>"
            echo "  tempdb clean"
            ;;
    esac
}

# ------------------------------------------
# 13. POST (Email Sender)
# ------------------------------------------
# Purpose: Send transactional emails via OCI SMTP.
# Usage:   post "subject" "body" "to@email.com"
#          echo "body" | post "subject" "to@email.com"
post() {
    local SUBJECT="$1"
    local BODY="$2"
    local TO="$3"

    # Handle Piped Input
    if [ ! -t 0 ]; then
        TO="$2"
        BODY=$(cat)
    fi

    if [ -z "$TO" ]; then 
        echo "Usage: post <subject> <body> <to_email>"
        echo "       echo <body> | post <subject> <to_email>"
        return 1
    fi

    # 1. Load Secrets
    local HOST=$(_get_key "OCI_SMTP_HOST")
    local USER=$(_get_key "OCI_SMTP_USER")
    local PASS=$(_get_key "OCI_SMTP_PASS")
    local FROM=$(_get_key "OCI_SMTP_FROM")

    if [[ -z "$HOST" || -z "$USER" || -z "$PASS" ]]; then
        echo "❌ Error: SMTP credentials missing in Vault."
        return 1
    fi

    echo "📧 Sending to $TO..."

    # 2. Python SMTP Script
    # We pass variables via Environment to avoid quoting hell
    export SMTP_HOST="$HOST"
    export SMTP_USER="$USER"
    export SMTP_PASS="$PASS"
    export SMTP_FROM="$FROM"
    export SMTP_TO="$TO"
    export SMTP_SUB="$SUBJECT"
    export SMTP_BODY="$BODY"

    python3 -c "
import smtplib, ssl, os, sys
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

try:
    msg = MIMEMultipart()
    msg['From'] = os.environ['SMTP_FROM']
    msg['To'] = os.environ['SMTP_TO']
    msg['Subject'] = os.environ['SMTP_SUB']
    msg.attach(MIMEText(os.environ['SMTP_BODY'], 'plain'))

    # Connect to OCI SMTP (Port 587 for STARTTLS)
    server = smtplib.SMTP(os.environ['SMTP_HOST'], 587)
    server.starttls()
    server.login(os.environ['SMTP_USER'], os.environ['SMTP_PASS'])
    server.sendmail(os.environ['SMTP_FROM'], os.environ['SMTP_TO'], msg.as_string())
    server.quit()
    print('✅ Sent.')
except Exception as e:
    print(f'❌ Failed: {e}')
    sys.exit(1)
"
}

# ==========================================
#  OCI LAUNCHER (The Master Menu)
# ==========================================
# Usage: oi
oi() {
    # 1. DYNAMICALLY LOCATE THIS FILE
    # This ensures the preview works regardless of where you save this script.
    # ${(%):-%x} is a ZSH specific flag to get the path of the current source script.
    local OCI_LIB="${(%):-%x}"

    # Fallback for Bash if you ever switch (BASH_SOURCE)
    if [ -z "$OCI_LIB" ]; then OCI_LIB="${BASH_SOURCE[0]}"; fi

    # 2. Define the menu
    local tools=(
        "basket:Private Storage (S3)"
        "site:Static Deployer (Public S3)"
        "drop:Public File Share"
        "buckets:Infrastructure Manager"
        "jam:MySQL HeatWave Interface"
        "pantry:Autonomous DB (SQL)"
        "kv:Key-Value Store (MySQL)"
        "stock:JSON Document Store"
        "task:Task Manager (MySQL)"
        "vault:Secret Manager (MySQL)"
    )

    # 3. Run FZF with 'awk' Paragraph Preview
    # This matches your AI Launcher logic: it reads THIS file ($OCI_LIB),
    # looks for the paragraph containing "func_name()", and prints it.

    local selected=$(printf "%s\n" "${tools[@]}" | column -t -s ":" | fzf \
            --height=60% \
            --layout=reverse \
            --border \
            --header="🍅 Tamatar Cloud Controller" \
            --prompt="Select Tool > " \
            --preview="awk -v func_name={1} 'BEGIN{RS=\"\"} \$0 ~ (\"(^|\\n)\" func_name \"\\\\(\\\\)\") {print}' $OCI_LIB | bat -l bash --color=always --style=numbers" \
            --preview-window="right:65%:wrap" \
        | awk '{print $1}')

    # 4. Push to Buffer (ZSH specific)
    if [[ -n "$selected" ]]; then
        print -z "$selected "
    fi
}
