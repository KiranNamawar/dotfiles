# =============================================================================
# CORE COMMANDS WITH MODERN REPLACEMENTS
# =============================================================================

# cd replacement with zoxide
alias cd='z'

# ls replacements with lsd
if command -v lsd &> /dev/null; then
    alias ls='lsd --color=always --group-dirs first'
    alias ll='lsd -l --color=always --group-dirs first'
    alias la='lsd -la --color=always --group-dirs first'
    alias lt='lsd --tree --color=always --group-dirs first'
    alias l.='lsd -la --color=always --group-dirs first | grep "^\."'
    alias l='lsd -la --color=always --group-dirs first'
    alias tree='lsd --tree --color=always'
else
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
fi

# cat replacement with bat
if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
    alias ccat='bat --paging=never --plain'
    alias bat='bat --paging=auto'
fi

# grep replacement with ripgrep
if command -v rg &> /dev/null; then
    alias grep='rg'
    alias rg='rg --color=auto --smart-case'
fi

# ps replacement with procs
if command -v procs &> /dev/null; then
    alias ps='procs'
fi

# top replacement with btm (bottom)
if command -v btm &> /dev/null; then
    alias top='btm'
    alias htop='btm'
fi

# du replacement with dust
if command -v dust &> /dev/null; then
    alias du='dust'
fi

# df replacement with duf
if command -v duf &> /dev/null; then
    alias df='duf'
fi


# =============================================================================
# SYSTEM INFORMATION
# =============================================================================

# Hardware info
alias cpu='lscpu'
alias mem='free -h'
alias disk='df -h'
alias temp='sensors'

# Network
alias myip='curl -s ifconfig.me'
alias localip='hostname -I'
alias ports='netstat -tuln'
alias listening='netstat -tuln | grep LISTEN'


# =============================================================================
# PACKAGE MANAGEMENT (ARCH LINUX)
# =============================================================================

# Pacman shortcuts
alias pac='sudo pacman'
alias paci='sudo pacman -S'
alias pacu='sudo pacman -Syu'
alias pacr='sudo pacman -R'
alias pacrs='sudo pacman -Rs'
alias pacss='pacman -Ss'
alias pacqi='pacman -Qi'
alias pacql='pacman -Ql'
alias pacqo='pacman -Qo'
alias pacclean='sudo pacman -Sc'
alias pacfull='sudo pacman -Scc'

# yay shortcuts (AUR helper)
if command -v yay &> /dev/null; then
    alias yayi='yay -S'
    alias yayrm='yay -Rs'
    alias yayu='yay -S'
fi


# =============================================================================
# GIT ALIASES
# =============================================================================

# Basic git operations
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gap='git add --patch'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gc='git commit'
alias gcm='git commit --message'
alias gca='git commit --amend'
alias gcam='git commit --amend --message'
alias gcan='git commit --amend --no-edit'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gdc='git diff --cached'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfa='git fetch --all'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gll='git log --graph --pretty=format:"%C(yellow)%h%C(reset) %C(blue)%an%C(reset) %C(green)%cr%C(reset) %s %C(red)%d%C(reset)"'
alias gm='git merge'
alias gp='git push'
alias gpa='git push --all'
alias gpu='git push --set-upstream origin'
alias gpl='git pull'
alias gpr='git pull --rebase'
alias gr='git reset'
alias grh='git reset --hard'
alias grs='git reset --soft'
alias gs='git status'
alias gss='git status --short'
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gstd='git stash drop'

# Advanced git operations
alias gclean='git clean -fd'
alias gundo='git reset --soft HEAD~1'
alias gwipe='git add -A && git commit -qm "WIPE SAVEPOINT" && git reset HEAD~1 --hard'
alias glog='git log --oneline --graph --decorate --all'
alias glogp='git log --pretty=format:"%h %s" --graph'

# Git with fzf integration
if command -v fzf &> /dev/null; then
    alias gbf='git branch | fzf | xargs git checkout'
    alias gcof='git log --oneline | fzf | cut -d" " -f1 | xargs git checkout'
fi

# Lazygit
if command -v lazygit &> /dev/null; then
    alias lg='lazygit'
fi


# =============================================================================
# NODE.JS / NPM/BUN/PNPM ALIASES
# =============================================================================

if command -v npm &> /dev/null; then
    alias n='npm'
    alias ni='npm install'
    alias nid='npm install --save-dev'
    alias nig='npm install --global'
    alias nr='npm run'
    alias ns='npm start'
    alias nt='npm test'
    alias nb='npm run build'
    alias ndev='npm run dev'
    alias nls='npm list'
    alias nout='npm outdated'
    alias nup='npm update'
    alias nci='npm ci'
    alias ncc='npm cache clean --force'
fi

if command -v bun &> /dev/null; then
    alias b='bun'
    alias bi='bun install'
    alias bid='bun install --save-dev'
    alias big='bun install --global'
    alias br='bun run'
    alias bs='bun start'
    alias bt='bun test'
    alias bb='bun build'
    alias bdev='bun dev'
    alias bls='bun list'
    alias bout='bun outdated'
    alias bup='bun update'
fi

if command -v pnpm &> /dev/null; then
    alias p='pnpm'
    alias pi='pnpm install'
    alias pid='pnpm install --save-dev'
    alias pig='pnpm install --global'
    alias pr='pnpm run'
    alias ps='pnpm start'
    alias pt='pnpm test'
    alias pb='pnpm build'
    alias pdev='pnpm dev'
    alias pls='pnpm list'
    alias pout='pnpm outdated'
    alias pup='pnpm update'
fi


# =============================================================================
# UTILITY ALIASES
# =============================================================================

# Quick edits
alias zshrc='${EDITOR} ~/.zshrc'

# Network
alias ping='ping -c 5'
alias wget='wget -c'
alias curl='curl -L'

# Archive management
alias tar='tar -xvf'
alias targz='tar -xzf'
alias tarbz='tar -xjf'
alias unzip='unzip -q'

# Utilities
alias v='nvim'
alias vi='nvim'
alias cl='clear'

# =============================================================================
# MODERN TOOL SPECIFIC ALIASES
# =============================================================================

# fzf enhanced commands
if command -v fzf &> /dev/null; then
    alias fzf='fzf --preview "bat --style=numbers --color=always --line-range :500 {}"'
    alias fzfp='fzf --preview "bat --style=numbers --color=always --line-range :500 {}"'
fi

# tldr
if command -v tldr &> /dev/null; then
    alias help='tldr'
    alias man='tldr'
fi

# zoxide
if command -v zoxide &> /dev/null; then
    alias j='z'
    alias ja='zi'
fi


# =============================================================================
# GLOBAL ALIASES (ZSH SPECIFIC)
# =============================================================================

# Pipe to common commands
alias -g L='| less'
alias -g G='| grep'
alias -g H='| head'
alias -g T='| tail'
alias -g S='| sort'
alias -g U='| uniq'
alias -g R='| rg'
alias -g F='| fzf'
alias -g J='| jq'
alias -g C='| wc -l'
alias -g N='| /dev/null'
alias -g N2='2>/dev/null'
alias -g NE='2>/dev/null'
alias -g DN='>/dev/null 2>&1'

# Common paths
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
