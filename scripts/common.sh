#!/usr/bin/env bash
# common.sh - Common definitions for shell scripts in dotfiles

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Text formatting
BOLD='\033[1m'
NORMAL='\033[0m'

# Print header function
print_header() {
  local title="$1"
  local term_width=${TERM_WIDTH:-$(tput cols)}
  local padding=$(( (term_width - ${#title}) / 2 ))
  printf "%${padding}s" ""
  echo -e "${BOLD}${BLUE}$title${NC}"
  printf '%*s
' "${term_width}" '' | tr ' ' '─'
}

# ---
# Function to check success for commands
check_success() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} $1"
  else
    echo -e "${RED}✗${NC} $1"
    if [[ -n "$2" && "$2" == "fatal" ]]; then
      echo -e "${RED}Fatal error. Exiting.${NC}"
      exit 1
    fi
  fi
}
# ---
