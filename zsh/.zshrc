# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Load secrets
if [ -f ~/.secrets.sh ]; then
    source ~/.secrets.sh
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export PATH="$HOME/.local/bin:$PATH"
# Force Zsh to show hidden files (dotfiles) in autocomplete
_comp_options+=(globdots)

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Add custom completions
fpath=(~/.dotfiles/zsh/completions $fpath)

# Initialize completion system (if not already done by OMZ)
autoload -Uz compinit && compinit

# --- Tmux Auto-Start Configuration ---
# Automatically start tmux
ZSH_TMUX_AUTOSTART=true
# Auto-connect to the session named "main" (or create it)
ZSH_TMUX_AUTOCONNECT=true
# Name the default session
ZSH_TMUX_DEFAULT_SESSION_NAME="main"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf fzf-tab tmux)

source $ZSH/oh-my-zsh.sh

# User configuration

# --- Load functions ---
if [ -f ~/.dotfiles/zsh/functions.zsh ]; then
    source ~/.dotfiles/zsh/functions.zsh
fi

# export MANPATH="/usr/local/man:$MANPATH"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Initialize Zoxide (Smart CD)
eval "$(zoxide init zsh)"

# Aliases
alias cat="bat -pP"
alias ls='lsd --group-directories-first'
alias ll='lsd -l --group-directories-first'
alias la='lsd -la --group-directories-first'
alias tree='lsd --tree'

alias sqlite='litecli'


# fnm
FNM_PATH="/home/kiran/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

# starship
eval "$(starship init zsh)"

# atuin
export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"
bindkey '^r' atuin-search

stty -ixon
# Now bind it
bindkey '^s' fzf-history-widget

# (Keep your Up Arrow as default Zsh history)
bindkey '^[[A' up-line-or-search
bindkey '^[OA' up-line-or-search

# zellij auto startup
# eval "$(zellij setup --generate-auto-start zsh)"


# --- FZF Configuration ---

# 1. Use 'fd' instead of 'find' (Faster, respects .gitignore)
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'

# 2. Apply 'bat' preview to EVERYTHING
# --border: Looks cleaner
# --preview: Shows file content on the right
export FZF_DEFAULT_OPTS="
  --height 60% 
  --border 
  --preview 'bat --style=numbers --color=always --line-range :500 {}'
  --bind 'ctrl-/:toggle-preview'
"

# --- FZF-TAB Styling (The "Pro" Look) ---

# 1. Force Zsh to use the "Menu" style (Required for fzf-tab to takeover)
zstyle ':completion:*' menu no

# 2. Format the descriptions (e.g. -- Description --)
# This enables the groups you saw in the screenshot
zstyle ':completion:*:descriptions' format '[%d]'

# 3. Colorize the list
# This makes the command green and the description gray/dim
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# 4. Allow toggling the preview window with Ctrl+/ inside the Tab menu
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-/:toggle-preview'

# 5. disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false

# 6. Smart Previews
# - For 'cd', 'ls', etc: Show directory contents with lsd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --color=always --icon=always $realpath'
# - For everything else (like your custom functions): No preview window unless it's a file
zstyle ':fzf-tab:complete:*:*' fzf-preview '
  if [[ -d $realpath ]]; then
    lsd -1 --color=always --icon=always $realpath
  elif [[ -f $realpath ]]; then
    bat --color=always --style=numbers --line-range=:500 $realpath
  fi'

# 5. Switch groups using < and > keys (Command vs Argument)
zstyle ':fzf-tab:*' switch-group '<' '>'

# bun completions
[ -s "/home/kiran/.bun/_bun" ] && source "/home/kiran/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"


