# ==========================================
#  ZSH CONFIGURATION
# ==========================================

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Path exports (Consolidated)
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$HOME/go/bin:$PATH"

# Force Zsh to show hidden files (dotfiles) in autocomplete
_comp_options+=(globdots)

# Add custom completions
fpath=(~/.dotfiles/zsh/completions $fpath)

# Initialize completion system
autoload -Uz compinit && compinit

# --- CUSTOM COMPLETIONS ---
# We source these manually because they contain grouped definitions
[ -f ~/.dotfiles/zsh/completions/oci_completions.zsh ]  && source ~/.dotfiles/zsh/completions/oci_completions.zsh
[ -f ~/.dotfiles/zsh/completions/ai_completions.zsh ]   && source ~/.dotfiles/zsh/completions/ai_completions.zsh
[ -f ~/.dotfiles/zsh/completions/util_completions.zsh ] && source ~/.dotfiles/zsh/completions/util_completions.zsh
[ -f ~/.dotfiles/zsh/completions/azr_completions.zsh ]  && source ~/.dotfiles/zsh/completions/azr_completions.zsh

# --- Secrets Loading ---
# 1. Load General Secrets
[ -f ~/.secrets.sh ] && source ~/.secrets.sh
# 2. Load OCI Secrets (Required for 'oi')
[ -f ~/.oci/.secrets.sh ] && source ~/.oci/.secrets.sh
# 3. Azure Secrets (Sky)
[ -f ~/.azure/.secrets.sh ] && source ~/.azure/.secrets.sh

# --- Tmux Auto-Start ---
ZSH_TMUX_AUTOSTART=true
ZSH_TMUX_AUTOCONNECT=true
ZSH_TMUX_DEFAULT_SESSION_NAME="main"

# --- Plugins ---
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf fzf-tab tmux)

source $ZSH/oh-my-zsh.sh

# ==========================================
#  TAMATAR OS (The Trilogy)
# ==========================================

# 1. Oracle Infrastructure (oi)
if [ -f ~/.dotfiles/zsh/oci_functions.zsh ]; then
    source ~/.dotfiles/zsh/oci_functions.zsh
fi

# 2. Azure Infrastructure (azr)
if [ -f ~/.dotfiles/zsh/azr_functions.zsh ]; then
    source ~/.dotfiles/zsh/azr_functions.zsh
fi

# 2. Artificial Intelligence (ai)
if [ -f ~/.dotfiles/zsh/ai_functions.zsh ]; then
    source ~/.dotfiles/zsh/ai_functions.zsh
fi

# 3. Local Utilities (util/sys)
# This file contains 'util', 'jqe', 'proj', etc.
if [ -f ~/.dotfiles/zsh/functions.zsh ]; then
    source ~/.dotfiles/zsh/functions.zsh
fi

# Dashboard Alias
alias tmt='echo -e "\n🍅 \033[1;31mTAMATAR OS\033[0m"; echo -e "  ☁️   oi    :: Cloud Infrastructure (OCI)"; echo -e "  ✈️   sky   :: Sky Infrastructure (Azure)"; echo -e "  🧠  ai    :: Intelligence"; echo -e "  ⚡  util  :: Local Utilities\n"'


# ==========================================
#  TOOLS & ALIASES
# ==========================================

# Initialize Zoxide (Smart CD)
eval "$(zoxide init zsh)"

# Aliases
alias cat="bat -pP"
alias ls='lsd --group-directories-first'
alias ll='lsd -l --group-directories-first'
alias la='lsd -la --group-directories-first'
alias tree='lsd --tree'
alias sqlite='litecli'

# fnm (Node Manager)
FNM_PATH="/home/kiran/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

# Starship Prompt
eval "$(starship init zsh)"

# Atuin (Shell History)
export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"
bindkey '^r' atuin-search

# Keybindings
stty -ixon
bindkey '^s' fzf-history-widget
bindkey '^[[A' up-line-or-search
bindkey '^[OA' up-line-or-search

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "/home/kiran/.bun/_bun" ] && source "/home/kiran/.bun/_bun"


# ==========================================
#  FZF & FZF-TAB STYLING
# ==========================================

# 1. Use 'fd' (Faster, respects .gitignore)
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'

# 2. General FZF Opts (The "Pro" Look)
export FZF_DEFAULT_OPTS="
  --height 60% 
  --border 
  --preview 'bat --style=numbers --color=always --line-range :500 {}'
  --bind 'ctrl-/:toggle-preview'
"

# 3. FZF-TAB (Tab Completion Styling)
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-/:toggle-preview'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':fzf-tab:*' switch-group '<' '>'

# Smart Previews for Tab Completion
# - Directories: Show tree with lsd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --color=always --icon=always $realpath'
# - Files/Others: Show content with bat
zstyle ':fzf-tab:complete:*:*' fzf-preview '
  if [[ -d $realpath ]]; then
    lsd -1 --color=always --icon=always $realpath
  elif [[ -f $realpath ]]; then
    bat --color=always --style=numbers --line-range=:500 $realpath
  fi'
