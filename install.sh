#!/bin/bash
# 🚀 Ultimate Dotfiles Installation Script
# Modern, safe, and comprehensive dotfiles setup
# Last updated: July 3, 2025

set -euo pipefail

# ===============================================================================
# CONFIGURATION AND CONSTANTS
# ===============================================================================

readonly DOTFILES_DIR="$HOME/dotfiles"
readonly BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="$HOME/.dotfiles_install.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Dotfiles to symlink (source:target)
declare -A DOTFILES=(
  [".zshrc"]="$HOME/.zshrc"
  [".tmux.conf"]="$HOME/.tmux.conf"
  [".gitignore"]="$HOME/.gitignore_global"
)

# Directories to symlink
declare -A DOTDIRS=(
  [".config/starship.toml"]="$HOME/.config/starship.toml"
  [".config/nvim"]="$HOME/.config/nvim"
  [".config/shell"]="$HOME/.config/shell"
)

# ===============================================================================
# UTILITY FUNCTIONS
# ===============================================================================

# Logging functions
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_status() {
  echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
  echo -e "\n${PURPLE}========================================${NC}"
  echo -e "${PURPLE} $1${NC}"
  echo -e "${PURPLE}========================================${NC}\n"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if running on supported system
check_system() {
  print_header "System Compatibility Check"

  local os_type=$(uname -s)
  print_status "Detected OS: $os_type"

  case "$os_type" in
    Linux)
      if [[ -f /etc/arch-release ]]; then
        print_success "Arch Linux detected - fully supported"
        export SYSTEM_TYPE="arch"
      elif grep -q Microsoft /proc/version 2>/dev/null; then
        print_success "WSL detected - supported"
        export SYSTEM_TYPE="wsl"
      else
        print_warning "Linux distribution not specifically supported, but should work"
        export SYSTEM_TYPE="linux"
      fi
      ;;
    Darwin)
      print_success "macOS detected - supported"
      export SYSTEM_TYPE="macos"
      ;;
    *)
      print_error "Unsupported operating system: $os_type"
      exit 1
      ;;
  esac
}

# Create backup of existing files
create_backup() {
  print_header "Creating Backup"

  if [[ ! -d "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    print_status "Created backup directory: $BACKUP_DIR"
  fi

  local backed_up=false

  # Backup dotfiles
  for dotfile in "${!DOTFILES[@]}"; do
    local target="${DOTFILES[$dotfile]}"
    if [[ -f "$target" ]] || [[ -L "$target" ]]; then
      cp -L "$target" "$BACKUP_DIR/$(basename "$target")" 2>/dev/null || true
      print_status "Backed up: $target"
      backed_up=true
    fi
  done

  # Backup directories
  for dotdir in "${!DOTDIRS[@]}"; do
    local target="${DOTDIRS[$dotdir]}"
    if [[ -d "$target" ]] || [[ -L "$target" ]]; then
      cp -rL "$target" "$BACKUP_DIR/$(basename "$target")" 2>/dev/null || true
      print_status "Backed up: $target"
      backed_up=true
    fi
  done

  if [[ "$backed_up" == true ]]; then
    print_success "Backup created at: $BACKUP_DIR"
  else
    print_status "No existing files to backup"
    rmdir "$BACKUP_DIR" 2>/dev/null || true
  fi
}

# Create symbolic links
create_symlinks() {
  print_header "Creating Symbolic Links"

  # Create necessary directories
  mkdir -p "$HOME/.config"

  # Symlink dotfiles
  for dotfile in "${!DOTFILES[@]}"; do
    local source="$DOTFILES_DIR/$dotfile"
    local target="${DOTFILES[$dotfile]}"

    if [[ -f "$source" ]]; then
      # Remove existing file/link
      [[ -e "$target" ]] || [[ -L "$target" ]] && rm -f "$target"

      # Create symlink
      ln -sf "$source" "$target"
      print_success "Symlinked: $dotfile -> $target"
    else
      print_warning "Source file not found: $source"
    fi
  done

  # Symlink directories
  for dotdir in "${!DOTDIRS[@]}"; do
    local source="$DOTFILES_DIR/$dotdir"
    local target="${DOTDIRS[$dotdir]}"
    local target_dir=$(dirname "$target")

    if [[ -e "$source" ]]; then
      # Create parent directory if needed
      mkdir -p "$target_dir"

      # Remove existing directory/link
      [[ -e "$target" ]] || [[ -L "$target" ]] && rm -rf "$target"

      # Create symlink
      ln -sf "$source" "$target"
      print_success "Symlinked: $dotdir -> $target"
    else
      print_warning "Source directory not found: $source"
    fi
  done
}

# Install prerequisites
install_prerequisites() {
  print_header "Installing Prerequisites"

  case "$SYSTEM_TYPE" in
    arch|wsl)
      if ! command_exists pacman; then
        print_error "Pacman not found. Are you sure this is Arch Linux?"
        exit 1
      fi

      print_status "Updating system packages..."
      sudo pacman -Syu --noconfirm

      print_status "Installing essential packages..."
      sudo pacman -S --needed --noconfirm \
        git curl wget unzip tar gzip \
        base-devel neovim tmux zsh \
        fzf ripgrep fd bat lsd dust duf \
        btop fastfetch xclip nodejs npm \
        python python-pip go rust
      ;;
    linux)
      if command_exists apt; then
        print_status "Updating system packages..."
        sudo apt update && sudo apt upgrade -y

        print_status "Installing essential packages..."
        sudo apt install -y \
          git curl wget unzip tar gzip \
          build-essential neovim tmux zsh \
          fzf ripgrep fd-find bat \
          nodejs npm python3 python3-pip \
          golang-go
      elif command_exists dnf; then
        print_status "Updating system packages..."
        sudo dnf update -y

        print_status "Installing essential packages..."
        sudo dnf install -y \
          git curl wget unzip tar gzip \
          @development-tools neovim tmux zsh \
          fzf ripgrep fd-find bat \
          nodejs npm python3 python3-pip \
          golang
      fi
      ;;
    macos)
      if ! command_exists brew; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi

      print_status "Installing essential packages..."
      brew install git curl wget unzip tar gzip \
        neovim tmux zsh fzf ripgrep fd bat \
        lsd dust duf btop fastfetch \
        node python go rust
      ;;
  esac

  print_success "Prerequisites installed"
}

# Install Oh My Zsh
install_oh_my_zsh() {
  print_header "Installing Oh My Zsh"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    print_status "Oh My Zsh already installed"
    return 0
  fi

  print_status "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

  # Install plugins
  local zsh_custom="$HOME/.oh-my-zsh/custom"

  print_status "Installing Zsh plugins..."

  # zsh-autosuggestions
  if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
  fi

  # zsh-syntax-highlighting
  if [[ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting"
  fi

  print_success "Oh My Zsh installed with plugins"
}

# Install modern tools
install_modern_tools() {
  print_header "Installing Modern CLI Tools"

  # Starship prompt
  if ! command_exists starship; then
    print_status "Installing Starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi

  # Zoxide
  if ! command_exists zoxide; then
    print_status "Installing Zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  fi

  # Atuin
  if ! command_exists atuin; then
    print_status "Installing Atuin..."
    bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)
  fi

  # LazyGit
  if ! command_exists lazygit; then
    case "$SYSTEM_TYPE" in
      arch|wsl)
        if command_exists yay; then
          yay -S --noconfirm lazygit
        elif command_exists paru; then
          paru -S --noconfirm lazygit
        else
          print_status "Installing Lazygit from GitHub..."
          local lazygit_version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
          curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${lazygit_version}_Linux_x86_64.tar.gz"
          tar xf lazygit.tar.gz lazygit
          sudo install lazygit /usr/local/bin
          rm lazygit lazygit.tar.gz
        fi
        ;;
      linux)
        print_status "Installing Lazygit from GitHub..."
        local lazygit_version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${lazygit_version}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit lazygit.tar.gz
        ;;
      macos)
        brew install lazygit
        ;;
    esac
  fi

  # Bun (JavaScript runtime)
  if ! command_exists bun; then
    print_status "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
  fi

  print_success "Modern CLI tools installed"
}

# Install tmux plugin manager
install_tmux_plugins() {
  print_header "Installing Tmux Plugin Manager"

  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ ! -d "$tpm_dir" ]]; then
    print_status "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    print_success "TPM installed"
    print_status "Run 'tmux' and press 'prefix + I' to install plugins"
  else
    print_status "TPM already installed"
  fi
}

# Setup development environment
setup_development() {
  print_header "Setting Up Development Environment"

  # Create common directories
  print_status "Creating development directories..."
  mkdir -p "$HOME/projects" "$HOME/work" "$HOME/notes" "$HOME/.local/bin"

  # Node.js tools
  if command_exists npm; then
    print_status "Installing global Node.js packages..."
    npm install -g typescript ts-node eslint prettier nodemon pnpm
  fi

  # Python tools
  if command_exists pip || command_exists pip3; then
    print_status "Installing Python packages..."
    python3 -m pip install --user black flake8 autopep8 pylint poetry jupyter ipython
  fi

  # Rust tools
  if command_exists cargo; then
    print_status "Installing Rust tools..."
    cargo install sccache cargo-watch cargo-edit
  fi

  print_success "Development environment setup complete"
}

# Configure Git
configure_git() {
  print_header "Configuring Git"

  # Check if git is already configured
  if git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1; then
    print_status "Git already configured"
    print_status "Name: $(git config --global user.name)"
    print_status "Email: $(git config --global user.email)"
    return 0
  fi

  # Configure git
  read -p "Enter your Git username: " git_username
  read -p "Enter your Git email: " git_email

  git config --global user.name "$git_username"
  git config --global user.email "$git_email"
  git config --global init.defaultBranch main
  git config --global core.editor "nvim"
  git config --global pull.rebase false
  git config --global core.excludesfile "$HOME/.gitignore_global"

  print_success "Git configured successfully"
}

# Change shell to zsh
change_shell() {
  print_header "Configuring Shell"

  if [[ "$SHELL" == *"zsh"* ]]; then
    print_status "Zsh is already the default shell"
    return 0
  fi

  local zsh_path
  if command_exists zsh; then
    zsh_path=$(command -v zsh)
    print_status "Changing default shell to: $zsh_path"
    chsh -s "$zsh_path"
    print_success "Default shell changed to Zsh"
    print_warning "Please restart your terminal or log out and back in"
  else
    print_error "Zsh not found"
    return 1
  fi
}

# Verify installation
verify_installation() {
  print_header "Verifying Installation"

  local errors=0

  # Check symlinks
  for dotfile in "${!DOTFILES[@]}"; do
    local target="${DOTFILES[$dotfile]}"
    if [[ -L "$target" ]] && [[ -e "$target" ]]; then
      print_success "✓ $dotfile symlinked correctly"
    else
      print_error "✗ $dotfile symlink failed"
      ((errors++))
    fi
  done

  # Check directories
  for dotdir in "${!DOTDIRS[@]}"; do
    local target="${DOTDIRS[$dotdir]}"
    if [[ -L "$target" ]] && [[ -e "$target" ]]; then
      print_success "✓ $dotdir symlinked correctly"
    else
      print_error "✗ $dotdir symlink failed"
      ((errors++))
    fi
  done

  # Check commands
  local commands=("zsh" "tmux" "nvim" "git" "starship" "fzf" "rg" "fd" "bat")
  for cmd in "${commands[@]}"; do
    if command_exists "$cmd"; then
      print_success "✓ $cmd available"
    else
      print_warning "⚠ $cmd not found"
    fi
  done

  if [[ $errors -eq 0 ]]; then
    print_success "Installation verification completed successfully"
  else
    print_error "Installation verification found $errors errors"
    return 1
  fi
}

# Cleanup function
cleanup() {
  print_header "Cleaning Up"

  # Remove temporary files
  rm -f /tmp/lazygit* 2>/dev/null || true

  print_status "Cleanup completed"
}

# Show final instructions
show_final_instructions() {
  print_header "Installation Complete!"

  cat << EOF
🎉 Your ultimate dotfiles have been installed successfully!

📋 Next Steps:
1. Restart your terminal or run: exec zsh
2. Open tmux and press 'prefix + I' to install tmux plugins
3. Open nvim and let it install plugins automatically
4. Configure Atuin: atuin register (optional)
5. Set up your SSH keys and Git repositories

🔧 Useful Commands:
- 'ez' to edit .zshrc
- 'etmux' to edit .tmux.conf
- 'ep' to edit starship prompt
- 'lg' to open LazyGit
- 'sz' to reload shell configuration

📚 Documentation:
- Starship: https://starship.rs/
- Tmux: https://github.com/tmux/tmux/wiki
- Neovim: https://neovim.io/doc/

🐛 Troubleshooting:
- Check the log file: $LOG_FILE
- Restore from backup: $BACKUP_DIR (if created)

Enjoy your irresistible terminal experience! 🚀
EOF
}

# Main installation function
main() {
  print_header "🚀 Ultimate Dotfiles Installation"

  # Start logging
  log "Starting dotfiles installation"

  # Check if dotfiles directory exists
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    print_error "Dotfiles directory not found at: $DOTFILES_DIR"
    print_status "Please clone the repository first:"
    print_status "git clone <repository_url> $DOTFILES_DIR"
    exit 1
  fi

  cd "$DOTFILES_DIR"

  # Run installation steps
  check_system
  create_backup
  install_prerequisites
  install_oh_my_zsh
  install_modern_tools
  install_tmux_plugins
  create_symlinks
  setup_development
  configure_git
  change_shell
  verify_installation
  cleanup
  show_final_instructions

  log "Dotfiles installation completed successfully"
}

# Error handling
trap 'print_error "Installation failed at line $LINENO. Check $LOG_FILE for details."; exit 1' ERR

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi