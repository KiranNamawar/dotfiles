# ------------------------------------------
# JQE (JSON Query Explorer)
# Usage: jqe file.json OR echo '{"a":1}' | jqe
# ------------------------------------------
jqe() {
  local INPUT_FILE=$(mktemp /tmp/jqe_XXXXXX.json)
  
  # 1. Input Handling: Pipe or File argument?
  if [ -f "$1" ]; then
    cat "$1" > "$INPUT_FILE"
  else
    # Read from Stdin (Piped input)
    # If stdin is empty, show usage
    if [ -t 0 ]; then
      echo "Usage: jqe <file> OR command | jqe"
      rm "$INPUT_FILE"
      return 1
    fi
    cat > "$INPUT_FILE"
  fi

  # 2. Check validity
  if ! jq empty "$INPUT_FILE" 2>/dev/null; then
    echo "❌ Error: Invalid JSON input."
    rm "$INPUT_FILE"
    return 1
  fi

  # 3. The Explorer Logic
  # We use JQ to generate a list of ALL paths (e.g. .user.name, .list[0].id)
  # Then feed that list to FZF
  local SELECTED_PATH=$(jq -r '
    paths 
    | map(if type=="number" then "["+tostring+"]" else "[\""+tostring+"\"]" end) 
    | join("") 
    | "." + .' "$INPUT_FILE" \
    | fzf --height 60% --layout=reverse --border \
          --header="JSON Explorer (Type to filter paths)" \
          --preview "jq -C {1} $INPUT_FILE" \
          --preview-window='right:60%:wrap')

  # 4. Cleanup & Output
  if [ -n "$SELECTED_PATH" ]; then
    # Extract the value at the selected path
    local VALUE=$(jq -r "$SELECTED_PATH" "$INPUT_FILE")
    
    # Copy to clipboard
    if command -v wl-copy &> /dev/null; then echo -n "$VALUE" | wl-copy
    elif command -v xclip &> /dev/null; then echo -n "$VALUE" | xclip -selection clipboard; fi
    
    echo "✅ Copied: $SELECTED_PATH"
    # Print value to stdout so it can be chained (e.g. jqe file | less)
    echo "$VALUE"
  fi

  rm "$INPUT_FILE"
}
