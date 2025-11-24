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
