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
      echo "Usage: stock {set <key.path> <val> | get <key.path> | ls | rm <key>}"
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
