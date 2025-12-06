#!/usr/bin/env zsh

# Source OCI functions to get 'jam' and 'daily' logic
# We suppress output to avoid cluttering the status bar
source ~/.dotfiles/zsh/oci_functions.zsh >/dev/null 2>&1

# Logic from 'daily ls' to find today's tasks
TODAY=$(date +%a | tr '[:upper:]' '[:lower:]')
WHERE_CLAUSE="
    ((schedule = 'daily') OR 
    (schedule = '$TODAY') OR
    (schedule = 'weekday' AND WEEKDAY(CURDATE()) < 5) OR
    (schedule = 'weekend' AND WEEKDAY(CURDATE()) >= 5))
    AND (last_done IS NULL OR last_done != CURDATE())
"

# Count remaining tasks
COUNT=$(jam -N -B -e "SELECT COUNT(*) FROM utils.habits WHERE $WHERE_CLAUSE;" 2>/dev/null)

if [[ -n "$COUNT" && "$COUNT" -gt 0 ]]; then
    echo "📅 $COUNT"
else
    echo ""
fi
