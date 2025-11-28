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
        local FILE="$1"
        local REMOTE="oracle:dropzone"
        local DOMAIN="drop.tamatar.dev"

        [ ! -f "$FILE" ] && echo "❌ File not found." && return 1
        echo "🍅 Dropping '$FILE'..."
        rclone copy "$FILE" "$REMOTE/" -P

        local FILENAME=$(basename "$FILE")
        local ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FILENAME'))")
        local URL="https://${DOMAIN}/${ENCODED}"
        _copy_to_clip "$URL"
        echo "✅ Link: $URL"
    }

    # ------------------------------------------
    # 4. BUCKETS (Infra Manager)
    # ------------------------------------------
    # Purpose: Generic CRUD for all OCI buckets.
    # Usage:   buckets mk <name>
    #          buckets ls [name]
    #          buckets sync <src> <dest>
    buckets() {
        local CMD=$1; local TARGET=$2; local REMOTE="oracle"
        case "$CMD" in
            ls)
                if [ -z "$TARGET" ]; then
                    # Clean output: Just the bucket names
                    echo "📦 Active Buckets:"
                    rclone lsd "$REMOTE:" | awk '{print $NF}' | sed 's/^/  - /'
                else
                    # Listing contents
                    rclone lsf "$REMOTE:$TARGET"
                fi
                ;;
            mk) oci os bucket create --namespace "$OCI_NS" --name "$TARGET" --storage-tier Standard --public-access-type NoPublicAccess ;;
            rm) rclone purge "$REMOTE:$TARGET" ;;
            sync) rclone sync "$2" "$REMOTE:$3" -P ;;
            nuke)
                # FORCE DELETE bucket + all hidden versions
                if [ -z "$TARGET" ]; then echo "Usage: buckets nuke <name>"; return 1; fi
                echo -n "☢️  Destroy ALL versions in '$TARGET'? [y/N] "
                read -r confirm
                if [[ "$confirm" == "y" ]]; then
                    oci os object bulk-delete-versions --namespace "$OCI_NS" --bucket-name "$TARGET" --force
                    oci os bucket delete --namespace "$OCI_NS" --name "$TARGET" --force
                    echo "✅ Obliterated."
                fi
                ;;
            *) echo "Usage: buckets {ls | mk | rm | sync}" ;;
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
        local CMD=$1; local KEY=$2; local VAL=$3
        _esc() { echo "${1//\'/\'\'}"; }
        case "$CMD" in
            set) jam -e "INSERT INTO utils.store (k,v) VALUES ('$(_esc "$KEY")','$(_esc "$VAL")') ON DUPLICATE KEY UPDATE v='$(_esc "$VAL")';" ;;
            get) jam -N -B -e "SELECT v FROM utils.store WHERE k='$(_esc "$KEY")';" ;;
            rm)  jam -e "DELETE FROM utils.store WHERE k='$(_esc "$KEY")';" ;;
            ls)
                local DATA=$(jam -N -B -e "SELECT k, v FROM utils.store ORDER BY k;")
                if command -v fzf &>/dev/null; then
                    echo "$DATA" | fzf --height 40% --layout=reverse --border --delimiter=$'\t' --with-nth=1 --preview='echo -e {2}' | cut -f2 | _copy_to_clip
            else echo "$DATA"; fi ;;
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
        local CMD=$1; local KEY=$2
        case "$CMD" in
            ls) pantrysh --quiet --eval "db.getSiblingDB('utils').stock.find({},{_id:1}).forEach(d => print(d._id))" ;;
            get) pantrysh --quiet --eval "EJSON.stringify(db.getSiblingDB('utils').stock.findOne({_id:'$KEY'}))" | jq . ;;
            *) echo "Usage: stock {set | get | ls}" ;;
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
            add) jam -e "INSERT INTO utils.tasks (content) VALUES ('${ARG//\'/\'\'}');"; echo "✅ Added." ;;
            ls)  jam -N -B -e "SELECT id, content FROM utils.tasks WHERE status='pending' ORDER BY id DESC;" | column -t -s $'\t' ;;
        done)
            local ID=$2
            [ -z "$ID" ] && ID=$(jam -N -B -e "SELECT id, content FROM utils.tasks WHERE status='pending';" | fzf --height 40% --layout=reverse | awk '{print $1}')
            [ -n "$ID" ] && jam -e "UPDATE utils.tasks SET status='done' WHERE id=$ID;" && echo "🎉 Done!" ;;
        clean) jam -e "DELETE FROM utils.tasks WHERE status='done';" ;;
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
    local CMD=$1; local KEY=$2; local VAL=$3
    case "$CMD" in
        add) jam -e "INSERT INTO utils.secrets (k,v,category) VALUES ('$KEY','$VAL','${4:-general}') ON DUPLICATE KEY UPDATE v='$VAL';" ;;
        load) export "$KEY"="$(jam -N -B -e "SELECT v FROM utils.secrets WHERE k='$KEY';")" ;;
        env)
            local CAT=$KEY; [ -z "$CAT" ] && CAT=$(jam -N -B -e "SELECT DISTINCT category FROM utils.secrets;" | fzf)
            while IFS=$'\t' read -r k v; do export "$k"="$v"; echo "🔓 $k"; done < <(jam -N -B -e "SELECT k, v FROM utils.secrets WHERE category='$CAT';") ;;
        ls) jam -N -B -e "SELECT category, k FROM utils.secrets ORDER BY category;" | column -t -s $'\t' ;;
        *) echo "Usage: vault {add | load | env | ls}" ;;
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
