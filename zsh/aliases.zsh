#!/usr/bin/env zsh
# ~/dotfiles/zsh/aliases.zsh
# 🚀 Smart Aliases for Ultimate Terminal Productivity
# Organized by category with intelligent defaults and modern tool integration
# Last updated: July 3, 2025

# ===============================================================================
# NAVIGATION - SMART & EFFICIENT
# ===============================================================================

# Basic navigation with enhanced functionality
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"
alias -- -="cd -"  # Go back to previous directory

# Quick directory access
alias config="cd ~/.config"
alias dot="cd ~/dotfiles"
alias scripts="cd ~/dotfiles/scripts"
alias downloads="cd ~/Downloads"
alias desktop="cd ~/Desktop"
alias documents="cd ~/Documents"

# Project directories with smart listing
alias proj="cd ~/projects && ls -la"
alias work="cd ~/work && ls -la"
alias notes="cd ~/notes && ls -la"
alias repos="cd ~/repositories && ls -la"

# Shell management
alias sz="source ~/.zshrc"
alias reload="exec zsh"
alias cls="clear && printf '\e[3J'"  # Clear screen and scrollback
alias reset-shell="exec $SHELL -l"

# ===============================================================================
# FILE LISTING - MODERN AND BEAUTIFUL
# ===============================================================================

# Basic listing with lsd (or fallback to ls)
if command -v lsd &> /dev/null; then
  alias ls="lsd --group-dirs first"
  alias l="lsd -l --group-dirs first"
  alias ll="lsd -la --group-dirs first"
  alias la="lsd -A --group-dirs first"
  alias lt="lsd --tree --depth=2"
  alias ltree="lsd --tree"
  alias lsize="lsd -la --total-size --size-sort"
  alias ldate="lsd -la --date-sort"
  alias lext="lsd -la --extenstion-sort"
else
  alias l="ls -lFh --color=auto"
  alias ll="ls -laFh --color=auto"
  alias la="ls -A --color=auto"
  alias lt="tree -L 2"
  alias ltree="tree"
fi

# File operations with safety and feedback
alias cp="cp -iv"
alias mv="mv -iv"
alias rm="rm -iv"
alias mkdir="mkdir -pv"
alias rmdir="rmdir -v"

# File permissions (octal and symbolic)
alias lso="ls -la | awk '{k=0;for(i=0;i<=8;i++)k+=((substr(\$1,i+2,1)~/[rwx]/)*2^(8-i));if(k)printf(\"%0o \",k);print}'"
alias chmodx="chmod +x"
alias chown-me="sudo chown -R \$USER:\$USER"

# ===============================================================================
# EDITORS AND CONFIGURATION
# ===============================================================================

# Editor shortcuts
alias v="nvim"
alias vim="nvim"
alias vi="nvim"
alias e="nvim"
alias edit="nvim"

# Quick config editing
alias ez="nvim ~/.zshrc"
alias ea="nvim ~/dotfiles/zsh/aliases.zsh"
alias ef="nvim ~/dotfiles/zsh/functions.zsh"
alias ee="nvim ~/dotfiles/zsh/exports.zsh"
alias ev="nvim ~/.config/nvim/init.lua"
alias ep="nvim ~/.config/starship.toml"
alias etmux="nvim ~/.tmux.conf"
alias egit="nvim ~/.gitconfig"
alias essh="nvim ~/.ssh/config"

# Project files
alias edot="nvim ~/dotfiles/PLAN.md"
alias ereadme="nvim README.md"
alias epackage="nvim package.json"
alias ecompose="nvim docker-compose.yml"
alias edocker="nvim Dockerfile"

# ===============================================================================
# GIT WORKFLOW - COMPREHENSIVE AND EFFICIENT
# ===============================================================================

# Status and information
alias gs="git status --short"
alias gss="git status"
alias gl="git log --oneline --graph --decorate --all"
alias glog="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
alias glp="git log --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=short"
alias gcount="git shortlog -sn"

# Basic operations
alias ga="git add"
alias gaa="git add ."
alias gap="git add -p"  # Interactive staging
alias gc="git commit -m"
alias gca="git commit --amend"
alias gcane="git commit --amend --no-edit"
alias gcm="git commit -m"
alias gce="git commit --allow-empty -m"

# Branch management
alias gb="git branch"
alias gba="git branch -a"
alias gbd="git branch -d"
alias gbD="git branch -D"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gcom="git checkout main || git checkout master"
alias gcod="git checkout develop"

# Remote operations
alias gp="git push"
alias gpu="git push -u origin"
alias gpo="git push origin"
alias gpf="git push --force-with-lease"
alias pull="git pull"
alias gpr="git pull --rebase"
alias gf="git fetch"
alias gfa="git fetch --all"

# Diff and merge
alias gd="git diff"
alias gdc="git diff --cached"
alias gdh="git diff HEAD"
alias gds="git diff --staged"
alias gdt="git difftool"

# Stash operations
alias gstash="git stash"
alias gstp="git stash pop"
alias gstl="git stash list"
alias gsts="git stash show"
alias gstd="git stash drop"

# Reset and cleanup
alias gr="git reset"
alias grh="git reset --hard"
alias grs="git reset --soft"
alias grhh="git reset --hard HEAD"
alias gclean="git clean -fd"
alias gdiscrad="git checkout -- ."

# Utilities
alias gcl="git clone"
alias gremote="git remote -v"
alias gtags="git tag -l"
alias gsummary="git status -s && echo '---' && git diff --stat"
alias gignore="git update-index --assume-unchanged"
alias gunignore="git update-index --no-assume-unchanged"

# ===============================================================================
# PACKAGE MANAGERS - STREAMLINED WORKFLOWS
# ===============================================================================

# Node.js ecosystype
alias n="npm"
alias ni="npm install"
alias nid="npm install --save-dev"
alias nig="npm install -g"
alias nu="npm uninstall"
alias nup="npm update"
alias nrun="npm run"
alias nstart="npm start"
alias ntest="npm test"
alias nbuild="npm run build"
alias ndev="npm run dev"
alias nlint="npm run lint"

# PNPM (preferred)
alias pn="pnpm"
alias pni="pnpm install"
alias pna="pnpm add"
alias pnad="pnpm add -D"
alias pnag="pnpm add -g"
alias pnr="pnpm remove"
alias pnup="pnpm update"
alias pnrun="pnpm run"
alias pnstart="pnpm start"
alias pndev="pnpm dev"
alias pnbuild="pnpm build"
alias pntest="pnpm test"

# Bun (fastest)
alias b="bun"
alias bi="bun install"
alias ba="bun add"
alias bad="bun add -d"
alias br="bun remove"
alias brun="bun run"
alias bstart="bun start"
alias bdev="bun dev"
alias bbuild="bun build"
alias btest="bun test"

# Yarn
alias y="yarn"
alias ya="yarn add"
alias yad="yarn add --dev"
alias yr="yarn remove"
alias yup="yarn upgrade"
alias yrun="yarn run"

# Python package managers
alias pi="pip install"
alias pir="pip install -r requirements.txt"
alias piup="pip install --upgrade"
alias pun="pip uninstall"
alias pfreeze="pip freeze > requirements.txt"
alias poetry="poetry"
alias po="poetry"
alias poins="poetry install"
alias poadd="poetry add"
alias porm="poetry remove"
alias porun="poetry run"
alias poshell="poetry shell"

# Rust package manager
alias cargo="cargo"
alias cb="cargo build"
alias cr="cargo run"
alias ct="cargo test"
alias cc="cargo check"
alias cu="cargo update"
alias ci="cargo install"
alias cclean="cargo clean"

# ===============================================================================
# SYSTEM MANAGEMENT - MONITORING AND MAINTENANCE
# ===============================================================================

# Process management
if command -v btop &> /dev/null; then
  alias top="btop"
  alias htop="btop"
  alias mem="btop --memory-tab"
  alias cpu="btop --cpu-tab"
elif command -v htop &> /dev/null; then
  alias top="htop"
fi

# Disk usage and management
if command -v duf &> /dev/null; then
  alias df="duf"
  alias diskspace="duf"
fi

if command -v dust &> /dev/null; then
  alias du="dust"
  alias usage="dust -r"
fi

# Network utilities
alias ports="sudo lsof -i -P -n | grep LISTEN"
alias netstat="ss -tuln"
alias ping="ping -c 5"
alias myip="curl ifconfig.me && echo"
alias localip="ip addr show | grep -o 'inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | grep -v 127.0.0.1"

# System information
alias sysinfo="fastfetch"
alias neofetch="fastfetch"
alias map="telnet mapscii.me"

# ===============================================================================
# ARCH LINUX PACKAGE MANAGEMENT
# ===============================================================================

# Pacman shortcuts
alias pac="sudo pacman"
alias pacs="sudo pacman -S"
alias pacr="sudo pacman -Rns"
alias pacu="sudo pacman -Syu"
alias pacc="sudo pacman -Sc"
alias pacq="pacman -Qdt"
alias paci="pacman -Qi"
alias pacf="pacman -Ql"
alias pacss="pacman -Ss"

# AUR helper (yay)
alias yay="yay"
alias yays="yay -S"
alias yayu="yay -Syu"
alias yayc="yay -Sc"
alias yayss="yay -Ss"

# System maintenance
alias update="sudo pacman -Syu"
alias update-all="yay -Syu"
alias cleanup="sudo pacman -Rns \$(pacman -Qtdq) 2>/dev/null || echo 'Nothing to clean'"
alias autoremove="sudo pacman -Rns \$(pacman -Qtdq)"
alias orphans="pacman -Qdt"

# ===============================================================================
# MODERN CLI TOOLS - ENHANCED REPLACEMENTS
# ===============================================================================

# File operations
if command -v bat &> /dev/null; then
  alias cat="bat"
  alias ccat="bat --style=plain"  # plain cat
fi

if command -v fd &> /dev/null; then
  alias find="fd"
  alias findf="fd"
fi

if command -v rg &> /dev/null; then
  alias grep="rg"
  alias egrep="rg"
  alias fgrep="rg -F"
fi

if command -v zoxide &> /dev/null; then
  alias cd="z"
  alias zi="zi"  # Interactive selection
fi

# Clipboard operations
if [[ "$IS_WSL" -eq 1 ]]; then
  alias copy="clip.exe"
  alias paste="powershell.exe -command 'Get-Clipboard'"
elif [[ "$IS_MACOS" -eq 1 ]]; then
  alias copy="pbcopy"
  alias paste="pbpaste"
else
  alias copy="xclip -selection clipboard"
  alias paste="xclip -selection clipboard -o"
fi

# ===============================================================================
# DEVELOPMENT TOOLS
# ===============================================================================

# Git tools
alias lg="lazygit"
alias tig="tig"

# Docker
alias d="docker"
alias dc="docker-compose"
alias dps="docker ps"
alias dim="docker images"
alias dex="docker exec -it"
alias dlogs="docker logs -f"
alias dclean="docker system prune -f"
alias dstop="docker stop \$(docker ps -q)"

# Kubernetes
alias k="kubectl"
alias kgp="kubectl get pods"
alias kgs="kubectl get services"
alias kgd="kubectl get deployments"
alias kdesc="kubectl describe"
alias klogs="kubectl logs -f"

# Web development
alias server="live-server"
alias tunnel="ngrok http"

# Database
alias mysql="mycli"
alias postgres="pgcli"

# ===============================================================================
# PRODUCTIVITY AND UTILITIES
# ===============================================================================

# Quick actions
alias q="exit"
alias :q="exit"
alias :wq="exit"
alias c="clear"
alias cl="clear"
alias cls="clear && printf '\e[3J'"
alias h="history"
alias j="jobs"
alias path="echo \$PATH | tr ':' '\n'"
alias reload-path="export PATH=\$(getconf PATH)"

# Date and time
alias now="date +'%Y-%m-%d %H:%M:%S'"
alias timestamp="date +%s"
alias iso="date --iso-8601=seconds"

# File compression
alias tar-create="tar -czf"
alias tar-extract="tar -xzf"
alias tar-list="tar -tzf"

# Permission helpers
alias 755="chmod 755"
alias 644="chmod 644"
alias 600="chmod 600"
alias chmodx="chmod +x"

# ===============================================================================
# HISTORY AND SEARCH
# ===============================================================================

# History management with atuin
if command -v atuin &> /dev/null; then
  alias hist="atuin search"
  alias histd="atuin search --cwd \$PWD"
  alias hists="atuin stats"
  alias histsync="atuin sync"
fi

# FZF-powered utilities
if command -v fzf &> /dev/null; then
  alias fzf-file="fzf --preview 'bat --color=always {}'"
  alias fzf-dir="find . -type d | fzf"
  alias fzf-hist="history | fzf"
fi

# ===============================================================================
# DEVELOPMENT SHORTCUTS
# ===============================================================================

# Quick project initialization
alias init-node="npm init -y"
alias init-ts="npx create-typescript-app"
alias init-react="npx create-react-app"
alias init-next="npx create-next-app"
alias init-vue="npx create-vue-app"
alias init-python="python -m venv .venv && source .venv/bin/activate && pip install --upgrade pip"

# Code quality
alias lint="npm run lint"
alias format="npm run format"
alias test="npm test"
alias coverage="npm run coverage"

# ===============================================================================
# MISCELLANEOUS AND FUN
# ===============================================================================

# Useful shortcuts
alias please="sudo"
alias fucking="sudo"
alias matrix="cmatrix"
alias starwars="telnet towel.blinkenlights.nl"

# Quick calculations
alias calc="bc -l"
alias random="shuf -i 1-100 -n 1"

# URL encoding/decoding
alias urlencode="python -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))'"
alias urldecode="python -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))'"

# JSON processing
alias json="jq ."
alias jsonl="jq -c ."

# ===============================================================================
# CONDITIONAL ALIASES
# ===============================================================================

# Load platform-specific aliases
case "$(uname -s)" in
  Darwin)
    # macOS specific aliases
    alias brew-update="brew update && brew upgrade && brew cleanup"
    alias flush-dns="sudo dscacheutil -flushcache"
    ;;
  Linux)
    # Linux specific aliases
    if command -v systemctl &> /dev/null; then
      alias service="systemctl"
      alias start="sudo systemctl start"
      alias stop="sudo systemctl stop"
      alias restart="sudo systemctl restart"
      alias status="systemctl status"
      alias enable="sudo systemctl enable"
      alias disable="sudo systemctl disable"
    fi
    ;;
esac

# ===============================================================================
# CUSTOM USER ALIASES
# ===============================================================================

# Load user-specific aliases (not tracked in git)
[[ -f "$HOME/.aliases.local" ]] && source "$HOME/.aliases.local"

