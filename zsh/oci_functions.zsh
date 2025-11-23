# ==========================================
#  OCI CLOUD UTILITIES (Tamatar Infrastructure)
# ==========================================

# 1. Load Secrets (Safe Password Handling)
# Ensure this file exports PANTRY_PASSWORD="..."
if [ -f ~/.oci/.secrets ]; then
    source ~/.oci/.secrets
fi

# ------------------------------------------
# 2. PANTRY (Oracle Autonomous DB 26ai)
# ------------------------------------------
pantry() {
  # Auto-encode password to handle special characters safely
  local PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$PANTRY_PASSWORD'))")
  
  # Connect via Mongosh
  # Added "$@" at the end to allow passing arguments (like --eval)
  mongosh "mongodb://ADMIN:$PASS@G3EEDDBE928C059-PANTRY.adb.ap-mumbai-1.oraclecloudapps.com:27017/ADMIN?authMechanism=PLAIN&authSource=\$external&ssl=true&retryWrites=false&loadBalanced=true" "$@"
}

# ------------------------------------------
# 3. JAM (Managed MySQL HeatWave)
# ------------------------------------------
# --- JAM (MySQL) ---
# Connected via Tailscale Mesh (Direct Private IP)
jam() {
  if [ -z "$JAM_PASS" ]; then echo "Set \$JAM_PASS first"; return 1; fi
  MYSQL_PWD="$JAM_PASS" mysql -h 10.0.1.57 -u admin "$@"
}


# ------------------------------------------
# 4. BASKET (Object Storage S3)
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
      if [ -z "$ARG1" ]; then echo "Usage: basket url <remote_file>"; return 1; fi
      echo "https://objectstorage.ap-mumbai-1.oraclecloud.com/n/$NS/b/$BUCKET/o/$ARG1"
      ;;
    *)
      echo "Commands: ls [prefix], push <file>, pull <file>, rm [-r] <name>, url <file>"
      ;;
  esac
}
