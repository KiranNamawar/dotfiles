# ==========================================
#  TAMATAR CLOUD INFRASTRUCTURE (Fedora)
# ==========================================

# --- 0. GLOBAL CONFIGURATION ---
# Cache Namespace/Region to speed up terminal launch
# (Run 'oci os ns get' once manually if this slows down shell startup)
[ -z "$OCI_NS" ] && export OCI_NS=$(oci os ns get --query data --raw-output 2>/dev/null)
export OCI_REGION="ap-mumbai-1"

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
  local REMOTE="oracle:website" # Or 'dropzone' if you made a separate bucket
  local DOMAIN="share.tamatar.dev" # Your Cloudflare Domain

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
# 4. DATABASES (Jam & Pantry)
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
