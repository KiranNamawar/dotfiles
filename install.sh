#!/usr/bin/env bash
#
# install.sh - Install all components for the Ultimate Terminal Experience
# Last updated: July 3, 2025

# Source common functions and definitions
source "$(dirname "$0")/scripts/common.sh"

# Path to dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
ZSH_DIR="$HOME/.oh-my-zsh"

# Check if running on Arch Linux in WSL
print_header "Environment Check"
if grep -q "Arch Linux" /etc/os-release; then
  echo -e "${GREEN}✓${NC} Arch Linux detected"
else
  echo -e "${YELLOW}⚠${NC} Not running on Arch Linux. Some features may not work as expected."
fi

if grep -q Microsoft /proc/version; then
  echo -e "${GREEN}✓${NC} WSL detected"
  WSL=true
else
  echo -e "${YELLOW}⚠${NC} Not running on WSL. WSL-specific features will be skipped."
  WSL=false
fi

# Install required packages
print_header "Installing required packages"
if command -v pacman &> /dev/null; then
  echo -e "${CYAN}Installing core packages...${NC}"
  sudo pacman -Syu --needed --noconfirm zsh tmux neovim git curl wget \
    base-devel lsd bat fd ripgrep fzf zoxide starship btop dust duf delta \
    tree jq unzip zip fastfetch
  check_success "Installed core packages"
  
  echo -e "${CYAN}Installing additional tools...${NC}"
  # Try installing with pacman first, then yay if available
  if command -v yay &> /dev/null; then
    yay -S --needed --noconfirm dog mcfly atuin navi grex gping bandwhich pastel tokei
    check_success "Installed additional tools via yay"
  else
    echo -e "${YELLOW}⚠${NC} yay not found. Skipping some optional packages."
    echo -e "${YELLOW}⚠${NC} Install yay for complete setup: git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
  fi
else
  echo -e "${YELLOW}⚠${NC} pacman not found. Please install required packages manually:"
  echo "zsh tmux neovim git curl wget lsd bat fd ripgrep fzf zoxide starship btop dust duf delta"
fi

# Install Oh My Zsh if not already installed
print_header "Setting up Oh My Zsh"
if [ ! -d "$ZSH_DIR" ]; then
  echo -e "${CYAN}Installing Oh My Zsh...${NC}"
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  check_success "Installed Oh My Zsh"
else
  echo -e "${GREEN}✓${NC} Oh My Zsh already installed"
fi

# Install Zsh plugins
echo -e "${CYAN}Installing Zsh plugins...${NC}"
ZSH_CUSTOM="$ZSH_DIR/custom"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  check_success "Installed zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  check_success "Installed zsh-syntax-highlighting"
fi

# Install tmux plugin manager
print_header "Setting up Tmux"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo -e "${CYAN}Installing Tmux Plugin Manager...${NC}"
  mkdir -p "$HOME/.tmux/plugins"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  check_success "Installed Tmux Plugin Manager"
else
  echo -e "${GREEN}✓${NC} Tmux Plugin Manager already installed"
fi

# Setup Starship prompt
print_header "Setting up Starship prompt"
if ! command -v starship &> /dev/null; then
  echo -e "${CYAN}Installing Starship prompt...${NC}"
  curl -sS https://starship.rs/install.sh | sh
  check_success "Installed Starship prompt"
else
  echo -e "${GREEN}✓${NC} Starship prompt already installed"
fi

# Create symlinks for configuration files
print_header "Setting up configuration files"
echo -e "${CYAN}Creating symlinks...${NC}"

# Create required directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR/nvim"

# Zsh
create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# Tmux
create_symlink "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"

# Starship
mkdir -p "$CONFIG_DIR/starship"
create_symlink "$DOTFILES_DIR/.config/starship.toml" "$CONFIG_DIR/starship.toml"

# Make scripts executable
print_header "Setting up scripts"
echo -e "${CYAN}Making scripts executable...${NC}"
chmod +x "$DOTFILES_DIR/scripts/"*
check_success "Made scripts executable"

# Final message
print_header "Installation complete!"
echo -e "${GREEN}${BOLD}Your ultimate terminal experience is ready!${NC}"
echo -e "To complete the setup:"
echo -e "1. Install tmux plugins: Start tmux and press ${BOLD}prefix + I${NORMAL} (prefix is Ctrl+a)"
echo -e "2. Change your default shell to Zsh: ${BOLD}chsh -s $(which zsh)${NORMAL}"
echo -e "3. Run ${BOLD}${DOTFILES_DIR}/scripts/validate-setup.sh${NORMAL} to verify your setup"
echo -e "\nEnjoy your irresistible terminal experience! 🚀"
