#!/bin/bash
# Advanced Shell Functions Usage Guide
# Your enhanced dotfiles come with powerful productivity functions

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            ADVANCED SHELL FUNCTIONS USAGE GUIDE             ║"
echo "║              How to Use Your Enhanced Terminal               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "🚀 PROJECT MANAGEMENT FUNCTIONS"
echo "──────────────────────────────────────────────────────────────"
echo "📁 project_init <name> [type]"
echo "   Creates a new project with proper setup:"
echo "   • project_init myapp node      # Creates Node.js project"
echo "   • project_init myapi python    # Creates Python project with venv"
echo "   • project_init mygame rust     # Creates Rust project with Cargo"
echo "   • project_init myservice go    # Creates Go project with modules"
echo "   • project_init myproject       # Creates general project"
echo ""
echo "   What it does:"
echo "   ✓ Creates directory and moves into it"
echo "   ✓ Initializes appropriate project structure"
echo "   ✓ Creates .gitignore with relevant patterns"
echo "   ✓ Initializes Git repository"
echo "   ✓ Makes initial commit"
echo ""

echo "🗂️ NAVIGATION FUNCTIONS"
echo "──────────────────────────────────────────────────────────────"
echo "📂 mkcd <directory>"
echo "   Creates directory and immediately moves into it:"
echo "   • mkcd ~/new-project/src"
echo ""
echo "🔍 smart_cd <partial-name>"
echo "   Intelligent directory navigation:"
echo "   • smart_cd dot      # Finds and goes to ~/dotfiles"
echo "   • smart_cd myapp    # Finds project directories"
echo "   Searches in: ~/projects, ~/work, ~/dotfiles"
echo ""

echo "🔎 SEARCH & FILE OPERATIONS"
echo "──────────────────────────────────────────────────────────────"
echo "📄 ff"
echo "   Fuzzy file finder with preview:"
echo "   • Just type 'ff' and search interactively"
echo "   • Uses bat for syntax highlighting"
echo "   • Press Enter to open in your editor"
echo ""
echo "🔍 search <pattern>"
echo "   Advanced code search with preview:"
echo "   • search \"function\"     # Finds all function definitions"
echo "   • search \"TODO\"        # Finds all TODO comments"
echo "   • search \"import.*react\" # Regex search for React imports"
echo "   • Press Enter to open file at exact line"
echo ""
echo "📦 extract <archive>"
echo "   Smart archive extraction:"
echo "   • extract file.tar.gz"
echo "   • extract archive.zip"
echo "   • extract package.7z"
echo "   Supports: .tar.gz, .zip, .7z, .rar, .tar.xz, and more"
echo ""

echo "🔧 GIT WORKFLOW HELPERS"
echo "──────────────────────────────────────────────────────────────"
echo "🧹 git_clean_branches"
echo "   Removes all merged branches (keeps main/master/develop):"
echo "   • git_clean_branches"
echo ""
echo "📦 git_squash_commits [count]"
echo "   Squashes recent commits:"
echo "   • git_squash_commits 3    # Squashes last 3 commits"
echo "   • git_squash_commits      # Squashes last 2 commits (default)"
echo ""

echo "🖥️ SYSTEM MONITORING"
echo "──────────────────────────────────────────────────────────────"
echo "⚡ top_processes"
echo "   Shows top CPU-consuming processes"
echo ""
echo "💾 disk_usage"
echo "   Shows disk usage sorted by usage percentage"
echo ""

echo "🛠️ DEVELOPMENT HELPERS"
echo "──────────────────────────────────────────────────────────────"
echo "🌐 serve [port]"
echo "   Starts a local HTTP server:"
echo "   • serve         # Starts on port 8000"
echo "   • serve 3000    # Starts on port 3000"
echo "   Great for testing static websites!"
echo ""
echo "📝 note [message]"
echo "   Daily note-taking system:"
echo "   • note                    # Opens today's note in editor"
echo "   • note \"Remember to...\"   # Adds timestamped note"
echo "   Notes saved to: ~/notes/YYYY-MM-DD.md"
echo ""

echo "💡 PRACTICAL USAGE EXAMPLES"
echo "──────────────────────────────────────────────────────────────"
echo ""
echo "🎯 Starting a new React project:"
echo "   project_init my-react-app node"
echo "   cd my-react-app"
echo "   npx create-react-app ."
echo ""
echo "🎯 Finding and editing a config file:"
echo "   ff                    # Opens fuzzy finder"
echo "   # Type: config.json"
echo "   # Press Enter to edit"
echo ""
echo "🎯 Searching for all API endpoints:"
echo "   search \"app\\.get\\|app\\.post\""
echo "   # Shows all Express.js routes with preview"
echo ""
echo "🎯 Quick project navigation:"
echo "   smart_cd myproject    # Finds ~/projects/myproject"
echo "   smart_cd dot          # Goes to ~/dotfiles"
echo ""
echo "🎯 Development workflow:"
echo "   mkcd temp-experiment  # Create and enter directory"
echo "   serve 8080           # Start local server"
echo "   note \"Testing new feature\""
echo ""
echo "🎯 Git cleanup after feature:"
echo "   git_squash_commits 4  # Squash last 4 commits"
echo "   git_clean_branches    # Remove merged branches"
echo ""

echo "⚡ PRO TIPS"
echo "──────────────────────────────────────────────────────────────"
echo "• All functions support tab completion"
echo "• Functions are available immediately in any new terminal"
echo "• Use 'type function_name' to see the function definition"
echo "• Functions integrate with your existing aliases and tools"
echo "• Error handling provides helpful feedback"
echo ""

echo "🔍 DISCOVERING MORE"
echo "──────────────────────────────────────────────────────────────"
echo "• View all functions: cat ~/.config/shell/functions/advanced.sh"
echo "• Check aliases: cat ~/dotfiles/zsh/aliases.zsh"
echo "• See integrations: cat ~/.config/shell/integrations.sh"
echo ""

echo "✨ Your terminal is now supercharged with these productivity functions!"
echo "Try them out and watch your development workflow become irresistible! 🚀"
