#!/bin/zsh

# 0. Wait for Internet
sleep 30

# 1. Load Secrets (Essential)
source $HOME/.oci/.secrets.sh
source $HOME/.dotfiles/zsh/other_functions.zsh # For 'notify'

# 2. Prepare Credentials (Replicating logic from pantrysh)
if [ -z "$PANTRY_PASSWORD" ] || [ -z "$PANTRY_HOST" ]; then
    notify "❌ Pantry Check Failed: Missing Secrets"
    exit 1
fi

# URL Encode Password (Python is reliable here)
PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$PANTRY_PASSWORD'))")

# 3. Run the Check
# We use 'timeout' on the actual binary 'mongosh', which works perfectly.
if timeout 10s mongosh "mongodb://ADMIN:$PASS@$PANTRY_HOST/ADMIN?authMechanism=PLAIN&authSource=\$external&ssl=true&retryWrites=false&loadBalanced=true" \
    --quiet --eval "db.runCommand({ping: 1})" >/dev/null 2>&1; then

    # Success
    notify "✅ Pantry Online" > /dev/null
else
    # Failure
    notify "❌ Pantry Unreachable" > /dev/null
fi
