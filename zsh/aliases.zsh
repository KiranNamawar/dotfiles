# ~/dotfiles/zsh/aliases.zsh

# === Navigation ===
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias config="cd ~/.config"
alias dot="cd ~/dotfiles"
alias sz="source ~/.zshrc"
alias reload="exec zsh"

# === Listing ===
alias l="lsd -l"
alias ll="lsd -la"
alias la="lsd -A"
alias lt="lsd --tree"
alias tree="lsd --tree"

# === Editor Shortcuts ===
alias v="nvim"
alias ez="nvim ~/.zshrc"
alias ep="nvim ~/.p10k.zsh"
alias ev="nvim ~/dotfiles/zsh"

# === Git Shortcuts ===
alias gs="git status"
alias ga="git add ."
alias gc="git commit -m"
alias gca="git commit --amend"
alias gp="git push"
alias gpo="git push origin"
alias gl="git log --oneline --graph --decorate"
alias gb="git branch"
alias gco="git checkout"
alias gd="git diff"
alias gcl="git clone"

# === Package Managers ===
alias n="npm"
alias pn="pnpm"
alias b="bun"
alias y="yarn"

# === Bun Utilities ===
alias bs="bun start"
alias bd="bun dev"
alias bi="bun install"

# === Arch Linux (pacman) ===
alias pacs="sudo pacman -S"
alias pacr="sudo pacman -Rns"
alias pacu="sudo pacman -Syu"
alias pacc="sudo pacman -Sc"
alias pacq="pacman -Qdt"

# === Clipboard & Output ===
alias copy="xclip -selection clipboard"
alias hist="history | fzf"
alias ports="sudo lsof -i -P -n | grep LISTEN"

# === Replacements ===
alias cat="bat"
alias findf="fd"
alias grep="rg"
alias top="btm"

# === LazyGit ===
alias lg="lazygit"

# === Web Utilities ===
alias weather="curl wttr.in"
alias ip="curl ifconfig.me"

# === System ===
alias update="sudo pacman -Syu"
alias cleanup="sudo pacman -Rns $(pacman -Qtdq)"
alias please="sudo"

# === Extras ===
alias :q="exit"
alias cl="clear"
alias path="echo $PATH | tr ':' '\n'"

