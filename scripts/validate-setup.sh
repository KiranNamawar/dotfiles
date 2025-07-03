#!/usr/bin/env bash
#
# validate-setup.sh - Verifies dotfiles and environment setup
# Part of the Irresistible Terminal Configuration

# Source common functions and definitions
source "$(dirname "$0")/common.sh"

echo -e "${BLUE}${BOLD}╔═════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║       DOTFILES VALIDATION TOOL      ║${NC}"
echo -e "${BLUE}${BOLD}╚═════════════════════════════════════╝${NC}\n"

# Keep track of successful and failed checks
total_checks=0
successful_checks=0

# Function to check the result of tests
check_result() {
  total_checks=$((total_checks+1))
  if [ "$1" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} $2"
    successful_checks=$((successful_checks+1))
  else
    echo -e "  ${RED}✗${NC} $2"
    echo -e "    ${YELLOW}→ $3${NC}"
  fi
}

echo -e "${BOLD}Checking Core Dependencies${NORMAL}"

# Check ZSH
if command -v zsh &> /dev/null; then
  zsh_version=$(zsh --version | cut -d' ' -f2)
  check_result 0 "ZSH installed (version $zsh_version)"
else
  check_result 1 "ZSH installed" "ZSH not found. Install with 'sudo pacman -S zsh'"
fi

# Check Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
  check_result 0 "Oh My Zsh installed"
else
  check_result 1 "Oh My Zsh installed" "Oh My Zsh not found. Install with: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

# Check Neovim
if command -v nvim &> /dev/null; then
  nvim_version=$(nvim --version | head -n 1 | cut -d' ' -f2)
  check_result 0 "Neovim installed (version $nvim_version)"
else
  check_result 1 "Neovim installed" "Neovim not found. Install with 'sudo pacman -S neovim'"
fi

# Check Tmux
if command -v tmux &> /dev/null; then
  tmux_version=$(tmux -V | cut -d' ' -f2)
  check_result 0 "Tmux installed (version $tmux_version)"
else
  check_result 1 "Tmux installed" "Tmux not found. Install with 'sudo pacman -S tmux'"
fi

# Check Starship
if command -v starship &> /dev/null; then
  starship_version=$(starship --version | cut -d' ' -f2)
  check_result 0 "Starship prompt installed (version $starship_version)"
else
  check_result 1 "Starship prompt installed" "Starship not found. Install with 'curl -sS https://starship.rs/install.sh | sh'"
fi

echo -e "\n${BOLD}Checking Essential Tools${NORMAL}"

# Modern terminal utilities
tools=("lsd" "bat" "fd" "rg" "fzf" "zoxide" "btop" "dust" "duf" "delta")
for tool in "${tools[@]}"; do
  if command -v "$tool" &> /dev/null; then
    check_result 0 "$tool installed"
  else
    check_result 1 "$tool installed" "$tool not found. Install with 'sudo pacman -S $tool' or check AUR"
  fi
done

echo -e "\n${BOLD}Checking Configuration Files${NORMAL}"

# Check dotfiles
config_files=(
  "$HOME/.zshrc"
  "$HOME/.tmux.conf"
  "$HOME/.config/starship.toml"
  "$HOME/.config/nvim"
)

for file in "${config_files[@]}"; do
  if [ -e "$file" ]; then
    check_result 0 "$file exists"
  else
    check_result 1 "$file exists" "File not found: $file"
  fi
done

# Check if WSL-specific settings are applied (if in WSL)
if grep -q Microsoft /proc/version; then
  echo -e "\n${BOLD}Checking WSL-Specific Configuration${NORMAL}"
  
  # Check Windows Terminal integration
  if [ -f "$HOME/dotfiles/windows-terminal-settings.json" ]; then
    check_result 0 "Windows Terminal settings available"
  else
    check_result 1 "Windows Terminal settings available" "Create windows-terminal-settings.json in your dotfiles"
  fi
  
  # Check clipboard integration
  if grep -q "clip.exe" "$HOME/.config/nvim/lua/config/options.lua" 2>/dev/null; then
    check_result 0 "Neovim clipboard integration for WSL configured"
  else
    check_result 1 "Neovim clipboard integration for WSL configured" "Add clipboard=unnamedplus and wsl-copy settings"
  fi
fi

echo -e "\n${BOLD}Summary${NORMAL}"
echo -e "Passed ${GREEN}$successful_checks${NC} of ${BLUE}$total_checks${NC} checks"

if [ "$successful_checks" -eq "$total_checks" ]; then
  echo -e "\n${GREEN}${BOLD}All checks passed! Your terminal setup is irresistible!${NC}"
else
  percent=$((successful_checks * 100 / total_checks))
  echo -e "\n${YELLOW}${BOLD}Setup is $percent% complete. Address the issues above to achieve terminal perfection.${NC}"
fi

# Return success only if all checks passed
[ "$successful_checks" -eq "$total_checks" ]
