# ~/dotfiles/zsh/aliases.zsh
# Smart Aliases for an Irresistible Terminal Experience

# === Navigation - Smart & Context-Aware ===
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias config="cd ~/.config"
alias dot="cd ~/dotfiles"
alias sz="source ~/.zshrc"
alias reload="exec zsh"

# Smart directory jumping with project awareness
alias proj="cd ~/projects && ls -la"
alias work="cd ~/work && ls -la"
alias notes="cd ~/notes && ls -la"

# === Enhanced Listing with Icons and Colors ===
alias l="lsd -l --group-dirs first"
alias ll="lsd -la --group-dirs first"
alias la="lsd -A --group-dirs first"
alias lt="lsd --tree --depth=2"
alias ltree="lsd --tree"
alias lsize="lsd -la --total-size --sizesort" # List by size

# === Editor Shortcuts with Context ===
alias v="nvim"
alias ez="nvim ~/.zshrc"
alias ev="nvim ~/dotfiles/zsh"
alias ep="nvim ~/.config/starship.toml"
alias edot="nvim ~/dotfiles/PLAN.md" # Edit dotfiles plan
alias etmux="nvim ~/.tmux.conf"

# === Git Workflow Accelerators ===
alias gs="git status"
alias ga="git add"
alias gaa="git add ."
alias gc="git commit -m"
alias gca="git commit --amend"
alias gp="git push"
alias gpo="git push origin"
alias gl="git pull"
alias glog="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
alias gsummary="git status -s && git diff --stat"
alias gb="git branch"
alias gco="git checkout"
alias gd="git diff"
alias gcl="git clone"

# === System Management ===
alias mem="btop --memory-tab" # Memory view in btop
alias cpu="btop --cpu-tab"    # CPU view in btop
alias diskspace="duf"         # Better df alternative
alias usage="dust -r"         # Disk usage with dust

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

# === Atuin (History Manager) ===
alias hist="atuin search"
alias histd="atuin search --cwd \$PWD"

