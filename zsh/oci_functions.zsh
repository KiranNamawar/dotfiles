# ==========================================
#  OCI CLOUD UTILITIES (Tamatar Infrastructure)
# ==========================================

# 1. Load Secrets (Safe Password Handling)
# Ensure this file exports PANTRY_PASSWORD="..."
if [ -f ~/.oci/.secrets ]; then
    source ~/.oci/.secrets
fi


# ------------------------------------------
# 2. JAM (Managed MySQL HeatWave)
# ------------------------------------------
# --- JAM (MySQL) ---
# Connected via Tailscale Mesh (Direct Private IP)
# jam() {
#   if [ -z "$JAM_PASS" ]; then echo "Set \$JAM_PASS first"; return 1; fi
#   MYSQL_PWD="$JAM_PASS" mysql -h 10.0.1.57 -u admin "$@"
# }
jam() {
  if [ -z "$JAM_PASS" ]; then echo "Set \$JAM_PASS first"; return 1; fi
  
  # If $1 is passed (like 'ecommerce_db'), use it. Otherwise, default to empty.
  local DB_TARGET="$1"
  
  # If we provided a DB name, shift arguments so extra flags work
  if [ -n "$DB_TARGET" ]; then shift; fi 

  MYSQL_PWD="$JAM_PASS" mysql -h 10.0.1.57 -u admin "$DB_TARGET" "$@"
}

# ------------------------------------------
# 3. BASKET (Object Storage S3)
# ------------------------------------------
basket() {
  if [ -z "$NS" ]; then export NS=$(oci os ns get | jq -r '.data'); fi
  local CMD=$1
  local ARG1=$2
  local ARG2=$3
  local BUCKET="basket"

  case "$CMD" in
    ls)
      oci os object list --namespace $NS --bucket-name $BUCKET \
          --prefix "$ARG1" --output table \
          --query "data[*].{Name:name, Size:size, Time:\"time-created\"}"
      ;;
    push)
      if [ -z "$ARG1" ]; then echo "Usage: basket push <file> [remote_name]"; return 1; fi
      local REMOTE_NAME="${ARG2:-$(basename "$ARG1")}"
      oci os object put --namespace $NS --bucket-name $BUCKET \
          --file "$ARG1" --name "$REMOTE_NAME" --force
      ;;
    rm)
      if [ -z "$ARG1" ]; then echo "Usage: basket rm <file> OR basket rm -r <folder>"; return 1; fi
      # Recursive Delete
      if [[ "$ARG1" == "-r" ]]; then
         local FOLDER=$ARG2
         if [ -z "$FOLDER" ]; then echo "Usage: basket rm -r <folder>"; return 1; fi
         echo "🔥 Deleting everything inside '$FOLDER'..."
         oci os object bulk-delete --namespace $NS --bucket-name $BUCKET --prefix "$FOLDER" --force
         echo "✅ Cleaned up '$FOLDER'"
         return 0
      fi
      # Single Delete
      if oci os object delete --namespace $NS --bucket-name $BUCKET --name "$ARG1" --force 2>/dev/null; then
         echo "🗑️ Deleted: $ARG1"
      else
         echo "❌ Error: Object '$ARG1' not found."
      fi
      ;;
    pull)
      if [ -z "$ARG1" ]; then echo "Usage: basket pull <remote_file>"; return 1; fi
      oci os object get --namespace $NS --bucket-name $BUCKET --name "$ARG1" --file "$(basename "$ARG1")"
      ;;
    url)
      if [ -z "$ARG1" ]; then echo "Usage: basket url <file>"; return 1; fi
      
      echo "🔗 Generating Magic Link for '$ARG1'..."
      
      # Calculate expiry (Works on Linux/GNU and MacOS/BSD)
      # Sets expiry to 24 hours from now
      if date --version >/dev/null 2>&1; then
          # Linux (GNU Date)
          local EXPIRY=$(date -u -d '+1 day' +%Y-%m-%dT%H:%M:%SZ)
      else
          # Mac (BSD Date)
          local EXPIRY=$(date -u -v+1d +%Y-%m-%dT%H:%M:%SZ)
      fi

      # Generate the Pre-Authenticated Request
      local PAR_PATH=$(oci os preauth-request create \
         --namespace $NS --bucket-name $BUCKET \
         --name "share_$(date +%s)" \
         --object-name "$ARG1" \
         --access-type ObjectRead \
         --time-expires "$EXPIRY" \
         --query "data.\"access-uri\"" --output raw)
      
      # Clean up output (sometimes contains quotes) and print
      # Note: PAR_PATH comes with a leading slash
      echo "https://objectstorage.ap-mumbai-1.oraclecloud.com${PAR_PATH}"
      ;;
    *)
      echo "Commands: ls [prefix], push <file>, pull <file>, rm [-r] <name>, url <file>"
      ;;
  esac
}

# ------------------------------------------
# 4. SITE (Public Web Hosting)
# ------------------------------------------
site() {
  if [ -z "$NS" ]; then export NS=$(oci os ns get --output json | jq -r '.data'); fi
  local CMD=$1
  local ARG1=$2
  local ARG2=$3
  local BUCKET="website"

  case "$CMD" in
    deploy)
      # Usage: site deploy <local_folder> [remote_name]
      local SITE_DIR="$ARG1"
      local REMOTE_NAME="$ARG2"

      if [ -z "$SITE_DIR" ]; then echo "Usage: site deploy <folder> [project_name]"; return 1; fi
      
      # 1. Build the base command arguments in an array
      local -a UPLOAD_OPTS
      UPLOAD_OPTS=(
        --namespace "$NS"
        --bucket-name "$BUCKET"
        --src-dir "$SITE_DIR"
        --overwrite
        --content-type auto
        --verify-checksum
      )

      local URL_SUFFIX=""
      
      # 2. Add the prefix if a project name is provided
      if [ -n "$REMOTE_NAME" ]; then
         UPLOAD_OPTS+=(--object-prefix "${REMOTE_NAME}/")
         URL_SUFFIX="${REMOTE_NAME}/"
         echo "🚀 Deploying '$SITE_DIR' -> '.../$REMOTE_NAME/'"
      else
         echo "🚀 Deploying '$SITE_DIR' -> Root (Main Site)"
      fi
      
      # 3. Execute (Using "${UPLOAD_OPTS[@]}" preserves the arguments correctly)
      oci os object bulk-upload "${UPLOAD_OPTS[@]}"
        
      echo "✅ Live at: https://objectstorage.ap-mumbai-1.oraclecloud.com/n/$NS/b/$BUCKET/o/${URL_SUFFIX}index.html"
      ;;
      
    ls)
      oci os object list --namespace $NS --bucket-name $BUCKET \
          --output table --query "data[*].{Name:name, Type:\"content-type\"}"
      ;;
      
    rm)
       if [ -z "$ARG1" ]; then echo "Usage: site rm <file> OR site rm -r <folder>"; return 1; fi
       if [[ "$ARG1" == "-r" ]]; then
          echo "🔥 Nuking folder '$2' from website..."
          # Note: If deleting a project, ensure you include the trailing slash, e.g., 'my-app/'
          oci os object bulk-delete --namespace $NS --bucket-name $BUCKET --prefix "$2" --force
       else
          oci os object delete --namespace $NS --bucket-name $BUCKET --name "$ARG1" --force
       fi
       ;;
       
    url)
      if [ -z "$ARG1" ]; then echo "Usage: site url <file_path>"; return 1; fi
      echo "https://objectstorage.ap-mumbai-1.oraclecloud.com/n/$NS/b/$BUCKET/o/$ARG1"
      ;;
      
    *)
      echo "Commands: deploy <folder> [name], ls, rm, url"
      ;;
  esac
}



# ------------------------------------------
# 5. PANTRY (SQL Interface - Default)
# ------------------------------------------
# Access: Wallet (mTLS) via SQLcl
pantry() {
  # Ensure environment is ready
  [ -z "$TNS_ADMIN" ] && export TNS_ADMIN="$HOME/.oci/wallet"
  [ -z "$PANTRY_PASSWORD" ] && [ -f ~/.oci/.secrets ] && source ~/.oci/.secrets

  if [ -n "$1" ]; then
     # Use CSV or JSON if requested, otherwise default to pretty ANSI
     local FORMAT="ansiconsole"
     if [[ "$1" == "--json" ]]; then FORMAT="json"; shift; fi
     if [[ "$1" == "--csv" ]]; then FORMAT="csv"; shift; fi
    
    sql -L /nolog <<EOF
connect ADMIN/"$PANTRY_PASSWORD"@pantry_high
set sqlformat ansiconsole;
$1
EXIT;
EOF
  else
     # Interactive Mode
     sql ADMIN/"$PANTRY_PASSWORD"@pantry_high
  fi
}



# ------------------------------------------
# 6. PANTRY-SH (Mongo Interface)
# ------------------------------------------
# Access: Public Endpoint via Mongosh
pantrysh() {
  # Check variables (Hostname is in secrets)
  if [ -z "$PANTRY_PASSWORD" ] || [ -z "$PANTRY_HOST" ]; then
    echo "Error: Credentials not set. Source ~/.oci/.secrets"
    return 1
  fi

  # Encode password for URL safety
  local PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$PANTRY_PASSWORD'))")
  
  # Connect
  mongosh "mongodb://ADMIN:$PASS@$PANTRY_HOST/ADMIN?authMechanism=PLAIN&authSource=\$external&ssl=true&retryWrites=false&loadBalanced=true" "$@"
}
