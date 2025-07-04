# � LazyVim Enhanced Configuration

A modern, feature-rich Neovim configuration built on top of [LazyVim](https://lazyvim.org/) with extensive customizations for development productivity, AI assistance, and WSL optimization.

## ✨ Features

### 🎨 **Modern UI & Themes**
- **Catppuccin** (default), Tokyo Night, Rose Pine, and Gruvbox colorschemes
- Animated and smooth UI transitions
- Enhanced highlighting and visual feedback
- WSL-optimized display settings

### 🤖 **AI-Powered Development**
- **GitHub Copilot** integration with chat functionality
- **Supermaven** alternative AI completion
- Intelligent code suggestions and generation
- AI-powered code explanations and reviews

### 📝 **Enhanced Editing**
- **Blink.cmp** for lightning-fast completion
- Advanced text objects with treesitter
- Smart commenting and code manipulation
- Multi-cursor support and enhanced yanking

### 🔧 **Development Tools**
- **LazyGit** integration for Git workflow
- **Toggleterm** with multiple terminal configurations
- **REST client** for API testing
- **Database UI** for database management
- **Markdown preview** with live updates

### 🌐 **Language Support**
- **TypeScript/JavaScript** with enhanced tooling
- **Python** with virtual environment support
- **Rust** with rust-tools and crates.nvim
- **Go** with comprehensive Go development tools
- **And many more** with proper LSP configuration

### 🖥️ **WSL Optimizations**
- Enhanced clipboard integration with Windows
- Performance optimizations for WSL environment
- File watching and backup optimizations
- WSL-specific terminal and browser configurations

## 🚀 **LazyVim Extras Included**

This configuration leverages many LazyVim extras:

- **AI**: `copilot`, `copilot-chat`, `supermaven`
- **Coding**: `blink`, `yanky`, `mini-surround`
- **Editor**: `aerial`, `fzf`, `harpoon2`, `inc-rename`, `leap`, `mini-diff`, `mini-files`, `outline`, `refactoring`
- **Languages**: `docker`, `git`, `go`, `json`, `markdown`, `python`, `rust`, `tailwind`, `typescript`, `yaml`
- **UI**: `edgy`, `mini-animate`, `mini-indentscope`, `smear-cursor`
- **Utils**: `chezmoi`, `dot`, `gitui`, `mini-hipatterns`, `project`
- **Testing**: `core` testing framework
- **DAP**: Debug Adapter Protocol support
- **Formatting**: `biome`, `prettier`
- **Linting**: `eslint`

## 📁 **Configuration Structure**

```
lua/
├── config/
│   ├── autocmds.lua      # Auto-commands and event handlers
│   ├── keymaps.lua       # Custom key mappings
│   ├── lazy.lua          # LazyVim bootstrap and setup
│   └── options.lua       # Neovim options and WSL optimizations
└── plugins/
    ├── ai.lua            # AI assistance and code generation
    ├── colorscheme.lua   # Themes and visual enhancements
    ├── editor.lua        # Enhanced editing experience
    ├── lang.lua          # Language-specific configurations
    └── tools.lua         # Development tools and utilities
```

## ⚡ **Key Mappings**

### **Leader Key**: `<Space>`

#### **AI & Copilot**
- `<leader>cc*` - Various Copilot Chat commands
- `<M-l>` - Accept Copilot suggestion
- `<M-]>/<M-[>` - Navigate suggestions

#### **File Operations**
- `<leader>ff` - Find files
- `<leader>fg` - Live grep
- `<leader>fb` - Find buffers
- `<leader>fr` - Recent files

#### **Git Integration**
- `<leader>gg` - LazyGit
- `<leader>gh*` - Git hunk operations
- `]h/[h` - Navigate git hunks

#### **Development Tools**
- `<leader>tt` - Toggle terminal
- `<leader>rr` - Run REST request
- `<leader>dd` - Database UI
- `<leader>mp` - Markdown preview

#### **Code Navigation**
- `<leader>cs` - Code outline (Aerial)
- `<leader>xx` - Diagnostics (Trouble)
- `gd` - Go to definition
- `gr` - Go to references

#### **Editing Enhancements**
- `jk/kj` - Exit insert mode
- `<leader>sr` - Search and replace (Spectre)
- `<leader>p` - Yank history
- `gcc` - Toggle comment

## 🛠️ **Installation**

This configuration is designed to work with the existing LazyVim setup. It extends LazyVim with additional functionality while maintaining compatibility.

### **Requirements**
- Neovim >= 0.9.0
- Git
- A Nerd Font (recommended: FiraCode Nerd Font)
- **For WSL**: Windows Terminal or similar

### **WSL-Specific Setup**
- Clipboard integration with Windows (`clip.exe`)
- Enhanced file watching and performance
- Terminal and browser optimizations

## 🔧 **Customization**

The configuration is highly modular and easy to customize:

1. **Add LazyVim Extras**: Edit `lazyvim.json` to include more extras
2. **Custom Plugins**: Add new plugins in the `lua/plugins/` directory
3. **Keymaps**: Modify `lua/config/keymaps.lua` for custom mappings
4. **Options**: Adjust settings in `lua/config/options.lua`

## 📚 **Documentation**

- [LazyVim Documentation](https://lazyvim.org/)
- [LazyVim Extras](https://lazyvim.org/extras)
- [Plugin Configurations](./lua/plugins/)

## 🤝 **Contributing**

Feel free to submit issues and enhancement requests!

## 📄 **License**

This configuration is released under the same license as LazyVim.

---

**Built with ❤️ using [LazyVim](https://lazyvim.org/)** LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.
