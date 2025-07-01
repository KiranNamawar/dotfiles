#!/usr/bin/env zsh

echo "⚙️  Starting dotfiles bootstrap..."

# Directories
DOTFILES="$HOME/dotfiles"
ZSH_CONFIG="$HOME/.zshrc"
P10K_CONFIG="$HOME/.p10k.zsh"
ZSH_DIR="$DOTFILES/zsh"

# --- Backup existing config if present ---
timestamp=$(date +%Y%m%d%H%M%S)
for file in .zshrc .p10k.zsh; do
  [ -f ~/$file ] && mv ~/$file ~/${file}.bak-$timestamp && echo "🔁 Backed up $file"
done

# --- Create symlinks ---
echo "🔗 Symlinking config files..."
ln -sf "$ZSH_DIR/aliases.zsh" ~/.aliases.zsh
ln -sf "$ZSH_DIR/exports.zsh" ~/.exports.zsh
ln -sf "$ZSH_DIR/functions.zsh" ~/.functions.zsh
ln -sf "$DOTFILES/.zshrc" ~/.zshrc
ln -sf "$DOTFILES/.p10k.zsh" ~/.p10k.zsh

# --- Create ~/.config if missing ---
mkdir -p ~/.config

# --- Optional: symlink Neovim config ---
if [ -d "$DOTFILES/.config/nvim" ]; then
  echo "📦 Linking Neovim config..."
  ln -sf "$DOTFILES/.config/nvim" ~/.config/nvim
fi

# --- Install Oh My Zsh if not installed ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "💾 Installing Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# --- Install Powerlevel10k if not present ---
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
  echo "🎨 Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
fi

# --- Install FZF if not present ---
if [ ! -d "$HOME/.fzf" ]; then
  echo "🔍 Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  yes | ~/.fzf/install
fi

# --- Install zoxide if not present ---
if ! command -v zoxide >/dev/null 2>&1; then
  echo "📦 Installing zoxide..."
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

echo "✅ Dotfiles setup complete. Restart your shell or run: exec zsh"

