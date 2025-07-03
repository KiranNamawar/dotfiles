# ~/.zshrc
# Irresistible Terminal Configuration for Arch Linux on WSL
# Last updated: July 3, 2025

# === Load Configuration Components ===
# Order matters: exports first, then functions, then aliases

# Load exports (environment variables)
if [[ -f "$HOME/dotfiles/zsh/exports.zsh" ]]; then
  source "$HOME/dotfiles/zsh/exports.zsh"
fi

# === Oh My Zsh Configuration ===
# These must be defined before loading Oh My Zsh
ZSH_THEME=""
plugins=(
  git
  zoxide
  sudo
  fzf
  history-substring-search
  zsh-autosuggestions
  zsh-syntax-highlighting
  # Conditional plugins based on environment (defined in exports.zsh)
  $([[ $IS_WSL -eq 1 ]] && echo "wsl")
  $([[ $SESSION_TYPE == "remote" ]] && echo "ssh")
  $([[ -x "$(command -v docker)" ]] && echo "docker docker-compose")
  $([[ -x "$(command -v kubectl)" ]] && echo "kubectl")
)

# === Shell Options ===
# History configuration
setopt HIST_IGNORE_ALL_DUPS  # Don't record duplicates in history
setopt HIST_FIND_NO_DUPS     # Don't display duplicates when searching
setopt HIST_SAVE_NO_DUPS     # Don't write duplicates to history file
setopt HIST_IGNORE_SPACE     # Don't record commands that start with a space
setopt SHARE_HISTORY         # Share history between sessions
setopt EXTENDED_HISTORY      # Record timestamp in history

# Directory navigation
setopt AUTO_CD              # `dirname` is the same as `cd dirname`
setopt AUTO_PUSHD           # Make cd push the old directory onto the stack
setopt PUSHD_IGNORE_DUPS    # Don't push multiple copies of the same directory
setopt PUSHD_SILENT         # Don't print the directory stack after pushd/popd

# Completion
setopt COMPLETE_IN_WORD     # Allow completion from within a word
setopt ALWAYS_TO_END        # Move cursor to end of completed word

# Load Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# === Load Additional Configurations ===
# Load modern shell functions and integrations
[[ -f ~/.config/shell/integrations.sh ]] && source ~/.config/shell/integrations.sh
[[ -f ~/.config/shell/functions/advanced.sh ]] && source ~/.config/shell/functions/advanced.sh

# Load aliases (must be after functions since some may use functions)
if [[ -f "$HOME/dotfiles/zsh/aliases.zsh" ]]; then
  source "$HOME/dotfiles/zsh/aliases.zsh"
fi

# === Prompt Configuration ===
# Initialize Starship prompt
eval "$(starship init zsh)"

# === Tool Initializations ===
# These should be after all other configurations

# FZF configuration (consolidated from exports.zsh)
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6ac,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6ac,hl+:#f38ba8"
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"

# Initialize nvm if installed
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# Initialize zoxide (modern alternative to cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# Initialize atuin (better history search) if installed
if command -v atuin &> /dev/null; then
  eval "$(atuin init zsh)"
fi

# === Welcome Message ===
# Display only in interactive shells
if [[ -t 1 && -n "$PS1" ]]; then
  display_welcome_message
fi

# === Additional Tool Completions ===
# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# FZF completion
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# === Package Manager Paths ===
# PNPM
export PNPM_HOME="/home/kiran/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Atuin environment
. "$HOME/.atuin/bin/env"

