# ~/.zshrc

# === Oh My Zsh Config ===
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Fix $PATH early
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"

# Enable Powerlevel10k instant prompt (before Oh My Zsh)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Plugins
plugins=(
  git
  z
  zoxide
  sudo
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Disable oh-my-zsh auto title
export DISABLE_AUTO_TITLE="true"
export ENABLE_CORRECTION="true"

source "$ZSH/oh-my-zsh.sh"

# === Extra Tools ===
eval "$(zoxide init zsh)"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# === Modular Sourcing ===
[[ -f ~/dotfiles/zsh/aliases.zsh ]] && source ~/dotfiles/zsh/aliases.zsh
[[ -f ~/dotfiles/zsh/exports.zsh ]] && source ~/dotfiles/zsh/exports.zsh
[[ -f ~/dotfiles/zsh/functions.zsh ]] && source ~/dotfiles/zsh/functions.zsh

