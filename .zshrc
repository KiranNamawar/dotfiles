#!/usr/bin/env zsh
# ~/.zshrc
# 🚀 Ultimate Zsh Configuration for Modern Development
# Optimized for performance, aesthetics, and productivity
# Last updated: July 3, 2025

# Performance: Start timing for optimization
if [[ "$PROFILE_STARTUP" == true ]]; then
  zmodload zsh/zprof
  PS4=$'%D{%M%S%.} %N:%i> '
  exec 3>&2 2>$HOME/.zsh_startup.log
  setopt xtrace prompt_subst
fi

# === Core Configuration Variables ===
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Create cache directory if it doesn't exist
[[ ! -d "$ZSH_CACHE_DIR" ]] && mkdir -p "$ZSH_CACHE_DIR"

# === Load Environment Variables First ===
# This must be loaded first as other configurations depend on these exports
if [[ -f "$DOTFILES_DIR/zsh/exports.zsh" ]]; then
  source "$DOTFILES_DIR/zsh/exports.zsh"
else
  echo "⚠️  Warning: exports.zsh not found at $DOTFILES_DIR/zsh/exports.zsh"
fi

# === Set default environment variables if not already set ===
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export IS_WSL="${IS_WSL:-0}"
export SESSION_TYPE="${SESSION_TYPE:-local}"

# === Oh My Zsh Configuration ===
# Performance: Only load if installed
if [[ -d "$ZSH" ]]; then
  # Disable automatic updates (we'll handle this manually)
  DISABLE_AUTO_UPDATE="true"
  DISABLE_UPDATE_PROMPT="true"

  # Performance: Disable unused features
  DISABLE_MAGIC_FUNCTIONS="true"
  DISABLE_AUTO_TITLE="true"

  # Theme: Use empty theme since we use Starship
  ZSH_THEME=""

  # Performance: Conditional plugin loading based on available tools
  plugins=(
    # Core plugins (always loaded)
    z
    git
    sudo
    colored-man-pages
  )

  # Add conditional plugins based on available tools
  [[ -x "$(command -v fzf)" ]] && plugins+=(fzf)
  [[ -x "$(command -v docker)" ]] && plugins+=(docker docker-compose)
  [[ -x "$(command -v kubectl)" ]] && plugins+=(kubectl)
  [[ -x "$(command -v npm)" ]] && plugins+=(npm)
  [[ -x "$(command -v yarn)" ]] && plugins+=(yarn)

  # Environment-specific plugins
  [[ $IS_WSL -eq 1 ]] && plugins+=(wsl)
  [[ $SESSION_TYPE == "remote" ]] && plugins+=(ssh-agent)

  # Must be last for proper functionality
  plugins+=(
    zsh-autosuggestions
    zsh-syntax-highlighting
    history-substring-search
  )

  # Load Oh My Zsh (suppress completion warnings)
  {
    source "$ZSH/oh-my-zsh.sh"
  } 2> >(grep -v '_arguments:comparguments:327: can only be called from completion function' >&2)
else
  echo "⚠️  Oh My Zsh not found. Install with: sh -c \"\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

# === Zsh Options & Settings ===
# History configuration - optimized for better search and deduplication
setopt HIST_IGNORE_ALL_DUPS     # Remove all duplicates from history
setopt HIST_FIND_NO_DUPS        # Don't show duplicates when searching
setopt HIST_SAVE_NO_DUPS        # Don't save duplicates to history file
setopt HIST_IGNORE_SPACE        # Ignore commands starting with space
setopt HIST_REDUCE_BLANKS       # Remove extra whitespace from history
setopt SHARE_HISTORY            # Share history between sessions
setopt EXTENDED_HISTORY         # Save timestamp and duration
setopt HIST_VERIFY              # Show command before execution when using !!

# Directory navigation - smart and efficient
setopt AUTO_CD                  # cd to directory just by typing its name
setopt AUTO_PUSHD               # Make cd push old directory onto stack
setopt PUSHD_IGNORE_DUPS        # Don't push duplicates onto stack
setopt PUSHD_SILENT             # Don't print stack after pushd/popd
setopt PUSHD_TO_HOME            # pushd with no arguments goes to home

# Completion system - enhanced experience
setopt COMPLETE_IN_WORD         # Complete from both ends of word
setopt ALWAYS_TO_END            # Move cursor to end after completion
setopt AUTO_MENU                # Show completion menu on tab
setopt AUTO_LIST                # List choices on ambiguous completion
setopt AUTO_PARAM_SLASH         # Add slash after completed directories
setopt COMPLETE_ALIASES         # Complete aliases

# Globbing and expansion - powerful pattern matching
setopt EXTENDED_GLOB            # Enable extended globbing
setopt GLOB_DOTS                # Include dotfiles in globbing
setopt NUMERIC_GLOB_SORT        # Sort numerically when possible
setopt NO_CASE_GLOB             # Case-insensitive globbing

# Job control - better background process handling
setopt LONG_LIST_JOBS           # List jobs in long format
setopt AUTO_RESUME              # Resume jobs by name
setopt NOTIFY                   # Report job status immediately
setopt NO_BG_NICE               # Don't nice background jobs
setopt NO_HUP                   # Don't send HUP to jobs when shell exits

# Error handling and correction
setopt CORRECT                  # Correct commands
setopt CORRECT_ALL              # Correct all arguments
setopt NO_BEEP                  # Disable all beeping

# === Load Core Functions ===
# Load functions before aliases since aliases may depend on functions
if [[ -f "$DOTFILES_DIR/zsh/functions.zsh" ]]; then
  source "$DOTFILES_DIR/zsh/functions.zsh"
fi

# === Load Shell Integrations ===
# Modern tool integrations for enhanced functionality
for integration_file in "$HOME/.config/shell/integrations.sh" "$HOME/.config/shell/functions/advanced.sh"; do
  [[ -f "$integration_file" ]] && source "$integration_file"
done

# === Load Aliases ===
# Load after functions to allow aliases to use custom functions
if [[ -f "$DOTFILES_DIR/zsh/aliases.zsh" ]]; then
  source "$DOTFILES_DIR/zsh/aliases.zsh"
fi

# === Enhanced Completion System ===
# Modern completion with caching for better performance
autoload -Uz compinit
autoload -Uz bashcompinit

# Ensure completion cache directory exists
[[ ! -d "$ZSH_CACHE_DIR/completions" ]] && mkdir -p "$ZSH_CACHE_DIR/completions"

# Performance: Only run compinit once per day
if [[ -n "$ZSH_CACHE_DIR"/compdump(#qN.mh+24) ]]; then
  compinit -C -d "$ZSH_CACHE_DIR/compdump"
else
  compinit -d "$ZSH_CACHE_DIR/compdump"
  # Touch file to reset timer
  touch "$ZSH_CACHE_DIR/compdump"
fi

bashcompinit

# === Key Bindings ===
# Enhanced key bindings for better navigation and editing
bindkey -e  # Use emacs key bindings

# History search with up/down arrows
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Enhanced navigation
bindkey '^[[1;5C' forward-word      # Ctrl+Right
bindkey '^[[1;5D' backward-word     # Ctrl+Left
bindkey '^[[3~' delete-char         # Delete
bindkey '^[[H' beginning-of-line    # Home
bindkey '^[[F' end-of-line          # End

# Quick directory navigation
bindkey -s '^O' 'cd ..\n'           # Ctrl+O: go up directory

# FZF function key bindings (only in interactive mode)
if [[ -o interactive ]] && [[ -n "$ZLE_REMOVE_SUFFIX_CHARS" ]]; then
  # Create ZLE widgets for fzf functions
  autoload -U edit-command-line
  zle -N edit-command-line
  
  # Define wrapper functions for ZLE
  _fzf_histfzf() { histfzf }
  _fzf_ff() { ff }
  _fzf_fcd() { fcd }
  _fzf_project_switch() { project_switch }
  
  # Register as ZLE widgets
  zle -N _fzf_histfzf
  zle -N _fzf_ff
  zle -N _fzf_fcd
  zle -N _fzf_project_switch
  
  # Bind keys to fzf functions
  bindkey '^R' _fzf_histfzf         # Ctrl+R: fuzzy history search
  bindkey '^T' _fzf_ff              # Ctrl+T: fuzzy file finder
  bindkey '^G' _fzf_fcd             # Ctrl+G: fuzzy directory navigation
  bindkey '^Y' _fzf_project_switch  # Ctrl+Y: project switcher
fi

# === Tool Initialization ===
# Initialize modern CLI tools for enhanced functionality

# Starship prompt - must be initialized after all other prompt configurations
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
else
  # Fallback prompt if starship is not installed
  PS1='%F{blue}%n@%m%f:%F{green}%~%f$ '
fi

# Zoxide - modern cd replacement with intelligence
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init --cmd cd zsh)"
fi

# Atuin - enhanced shell history
if command -v atuin &> /dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# FZF - fuzzy finder with custom configuration
if command -v fzf &> /dev/null; then
  # Enhanced FZF configuration
  export FZF_DEFAULT_OPTS="
    --height 80%
    --layout reverse
    --border rounded
    --info inline
    --preview-window border-rounded
    --prompt '🔍 '
    --pointer '→'
    --marker '✓'
    --color 'fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8'
    --color 'fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8'
    --color 'info:#cba6ac,prompt:#cba6ac,pointer:#f5e0dc'
    --color 'marker:#f5e0dc,spinner:#f5e0dc,header:#f38ba8'
    --bind 'ctrl-y:execute-silent(echo {} | xclip -selection clipboard)'
    --bind 'ctrl-e:become(nvim {})'
    --bind 'ctrl-v:toggle-preview'
    --bind 'ctrl-u:preview-page-up'
    --bind 'ctrl-d:preview-page-down'"

  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git --exclude node_modules"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git --exclude node_modules"

  # Load FZF key bindings and completion
  [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
fi

# Node Version Manager
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # Performance: Lazy load NVM
  nvm() {
    unfunction nvm
    source "$NVM_DIR/nvm.sh"
    nvm "$@"
  }
fi

# Direnv - automatic environment loading
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# GitHub CLI completion
if command -v gh &> /dev/null; then
  eval "$(gh completion -s zsh)"
fi

# === Plugin Configuration ===
# Configure loaded plugins for optimal experience

# Autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#585b70,underline"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=true

# Syntax highlighting
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
ZSH_HIGHLIGHT_PATTERNS=('rm -rf *' 'fg=white,bold,bg=red')

# History substring search
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="bg=green,fg=white,bold"
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="bg=red,fg=white,bold"
HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS="i"

# === Additional Tool Completions ===
# Load completions for additional tools

# Bun completion
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# Cargo completion
if command -v rustup &> /dev/null; then
  [[ ! -f "$ZSH_CACHE_DIR/cargo_completion" ]] && rustup completions zsh cargo > "$ZSH_CACHE_DIR/cargo_completion"
  source "$ZSH_CACHE_DIR/cargo_completion"
fi

# Poetry completion
if command -v poetry &> /dev/null; then
  [[ ! -f "$ZSH_CACHE_DIR/poetry_completion" ]] && poetry completions zsh > "$ZSH_CACHE_DIR/poetry_completion"
  source "$ZSH_CACHE_DIR/poetry_completion"
fi

# === Welcome Message & Session Info ===
# Display welcome message only in interactive, non-SSH sessions
if [[ -t 1 && -n "$PS1" && -z "$SSH_CLIENT" && -z "$SSH_TTY" ]]; then
  # Performance: Only show welcome message if function exists
  if declare -f display_welcome_message > /dev/null; then
    display_welcome_message
  fi
fi

# === Performance Profiling ===
# End timing if profiling is enabled
if [[ "$PROFILE_STARTUP" == true ]]; then
  unsetopt xtrace
  exec 2>&3 3>&-
  zprof > ~/.zsh_profile
fi

# === Final PATH Optimization ===
# Remove duplicate entries from PATH for better performance
typeset -U PATH path

# === Custom Hooks ===
# Load any local customizations (not tracked in git)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# === Cleanup ===
# Unset temporary variables
unset ZSH_CACHE_DIR

# Performance: Compile .zshrc for faster loading
if [[ ! -f ~/.zshrc.zwc || ~/.zshrc -nt ~/.zshrc.zwc ]]; then
  zcompile ~/.zshrc
fi

