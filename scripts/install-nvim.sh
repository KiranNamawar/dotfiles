#!/bin/bash

# Neovim Configuration Installation Script
# This script sets up the modern Neovim configuration

set -e

echo "🚀 Installing Neovim Configuration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Neovim is installed
if ! command -v nvim &> /dev/null; then
    print_error "Neovim is not installed. Please install Neovim first."
    exit 1
fi

# Check Neovim version
NVIM_VERSION=$(nvim --version | head -n1 | cut -d' ' -f2 | cut -d'v' -f2)
REQUIRED_VERSION="0.9.0"

if ! printf '%s\n' "$REQUIRED_VERSION" "$NVIM_VERSION" | sort -V -C; then
    print_error "Neovim version $NVIM_VERSION is too old. Required: $REQUIRED_VERSION+"
    exit 1
fi

print_success "Neovim version $NVIM_VERSION is compatible"

# Backup existing configuration
if [ -d "$HOME/.config/nvim" ]; then
    BACKUP_DIR="$HOME/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backing up existing configuration to $BACKUP_DIR"
    mv "$HOME/.config/nvim" "$BACKUP_DIR"
    print_success "Existing configuration backed up"
fi

# Create config directory
mkdir -p "$HOME/.config"

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/.config/nvim"

# Copy configuration if this script is in a dotfiles repo
if [ -d "$CONFIG_DIR" ]; then
    print_status "Copying configuration from $CONFIG_DIR"
    cp -r "$CONFIG_DIR" "$HOME/.config/nvim"
else
    print_error "Configuration directory not found at $CONFIG_DIR"
    exit 1
fi

# Check if we're in WSL
if [ -n "$WSL_DISTRO_NAME" ] || grep -qi microsoft /proc/version 2>/dev/null; then
    print_status "WSL detected - configuring clipboard integration"
    
    # Check for clip.exe
    if command -v clip.exe &> /dev/null; then
        print_success "clip.exe found for clipboard integration"
    else
        print_warning "clip.exe not found. Clipboard may not work properly."
        print_status "Make sure Windows paths are in your WSL PATH"
    fi
    
    # Check for powershell.exe
    if command -v powershell.exe &> /dev/null; then
        print_success "powershell.exe found for clipboard integration"
    else
        print_warning "powershell.exe not found. Clipboard paste may not work."
    fi
fi

# Check for essential dependencies
print_status "Checking dependencies..."

dependencies=(
    "git:Git version control"
    "node:Node.js for LSP servers"
    "npm:npm package manager"
)

for dep in "${dependencies[@]}"; do
    cmd="${dep%%:*}"
    desc="${dep#*:}"
    
    if command -v "$cmd" &> /dev/null; then
        print_success "$cmd found"
    else
        print_warning "$cmd not found - $desc may not work"
    fi
done

# Check for optional dependencies
print_status "Checking optional dependencies..."

optional_deps=(
    "python3:Python support for some plugins"
    "rg:ripgrep for better search performance"
    "fd:fd for better file finding"
    "fzf:fzf for fuzzy finding"
)

for dep in "${optional_deps[@]}"; do
    cmd="${dep%%:*}"
    desc="${dep#*:}"
    
    if command -v "$cmd" &> /dev/null; then
        print_success "$cmd found"
    else
        print_warning "$cmd not found - $desc (optional)"
    fi
done

print_status "Starting Neovim to install plugins..."

# Start Neovim to trigger plugin installation
nvim --headless -c "qa" 2>/dev/null || true

print_success "Configuration installed successfully!"
print_status "You can now start Neovim with 'nvim'"
print_status "Run ':checkhealth' in Neovim to verify everything is working"
print_status "Run ':Lazy' to manage plugins"

# Print key mappings reminder
echo ""
echo "🔧 Key Mappings:"
echo "  <Space>     - Leader key"
echo "  <Leader>ff  - Find files"
echo "  <Leader>fg  - Live grep"
echo "  <Leader>e   - Toggle file explorer"
echo "  <Leader>tt  - Toggle terminal"
echo ""
echo "📚 See README.md for full documentation"
echo "🎉 Happy coding!"
