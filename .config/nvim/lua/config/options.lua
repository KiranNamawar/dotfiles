-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ============================================================================
-- WSL-SPECIFIC OPTIMIZATIONS
-- ============================================================================

-- Enhanced WSL clipboard integration with better performance
if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = "/mnt/c/WINDOWS/system32/clip.exe",
      ["*"] = "/mnt/c/WINDOWS/system32/clip.exe",
    },
    paste = {
      ["+"] = "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -NonInteractive -Command Get-Clipboard",
      ["*"] = "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -NonInteractive -Command Get-Clipboard",
    },
    cache_enabled = 0, -- Disable cache for more reliable clipboard
  }
  
  -- WSL performance optimizations
  vim.opt.clipboard = "unnamedplus"
  vim.opt.updatetime = 100 -- Faster updates for WSL
  -- vim.opt.lazyredraw = true -- Don't redraw during macros (disabled due to Noice plugin conflicts)
  vim.opt.regexpengine = 1 -- Use old regex engine (faster in WSL)
  
  -- Disable swap and backup files for better WSL performance
  vim.opt.swapfile = false
  vim.opt.backup = false
  vim.opt.writebackup = false
  
  -- Better file watching in WSL
  vim.opt.fsync = false
end

-- ============================================================================
-- PERSONAL PREFERENCES & ENHANCEMENTS
-- ============================================================================

-- Enhanced editing experience
vim.opt.wrap = false -- Don't wrap long lines
vim.opt.linebreak = true -- Wrap at word boundaries if wrap is enabled
vim.opt.breakindent = true -- Indent wrapped lines
vim.opt.showbreak = "↪ " -- Show character at line breaks
vim.opt.scrolloff = 8 -- Keep 8 lines above/below cursor
vim.opt.sidescrolloff = 8 -- Keep 8 characters left/right of cursor
vim.opt.virtualedit = "block" -- Allow cursor to move freely in visual block mode

-- Enhanced search configuration
vim.opt.ignorecase = true -- Ignore case in search
vim.opt.smartcase = true -- Override ignorecase if search contains uppercase
vim.opt.gdefault = true -- Use global flag by default in substitute commands

-- Better completion experience
vim.opt.pumblend = 0 -- Remove popup menu transparency to prevent dashboard bleed-through
vim.opt.pumheight = 15 -- Maximum items in popup menu
vim.opt.completeopt = { "menuone", "noselect", "noinsert" }

-- Enhanced visual feedback
vim.opt.cursorline = true -- Highlight current line
vim.opt.cursorcolumn = false -- Don't highlight current column (can be slow)
vim.opt.colorcolumn = "80,120" -- Show rulers at 80 and 120 characters
vim.opt.list = true -- Show invisible characters
vim.opt.listchars = {
  tab = "→ ",
  trail = "•",
  nbsp = "␣",
  extends = "❯",
  precedes = "❮",
}

-- Enhanced folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = "v:lua.vim.treesitter.foldtext()"
vim.opt.foldcolumn = "1"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

-- Better window behavior
vim.opt.splitkeep = "screen" -- Reduce scroll during window split
vim.opt.splitbelow = true -- New horizontal splits below
vim.opt.splitright = true -- New vertical splits to the right

-- Enhanced command line
vim.opt.cmdheight = 0 -- Hide command line when not used
vim.opt.shortmess:append("c") -- Don't show completion messages
vim.opt.shortmess:append("I") -- Don't show intro message

-- Better diff options
vim.opt.diffopt:append("linematch:60") -- Better diff algorithm
vim.opt.diffopt:append("algorithm:histogram") -- Use histogram diff algorithm

-- Performance optimizations
vim.opt.synmaxcol = 300 -- Limit syntax highlighting to 300 columns
vim.opt.redrawtime = 10000 -- Max time for redrawing
vim.opt.timeoutlen = 300 -- Faster which-key display
vim.opt.ttimeoutlen = 0 -- Faster key sequence completion

-- Better undo experience
vim.opt.undofile = true -- Persistent undo
vim.opt.undolevels = 10000 -- More undo levels
vim.opt.undoreload = 10000 -- More undo reloads

-- Enhanced mouse support
vim.opt.mouse = "a" -- Enable mouse in all modes
vim.opt.mousefocus = true -- Focus follows mouse

-- Better session options
vim.opt.sessionoptions = {
  "buffers",
  "curdir",
  "tabpages",
  "winsize",
  "help",
  "globals",
  "skiprtp",
  "folds",
}

-- ============================================================================
-- MODERN NEOVIM FEATURES
-- ============================================================================

-- Enable newer Neovim features
if vim.fn.has("nvim-0.10") == 1 then
  vim.opt.smoothscroll = true -- Smooth scrolling
  vim.opt.foldtext = "" -- Use treesitter foldtext
end

-- Better diagnostic configuration
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
    spacing = 4,
  },
  float = {
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- ============================================================================
-- CUSTOM GLOBAL VARIABLES
-- ============================================================================

-- LazyVim specific configurations
vim.g.lazyvim_picker = "telescope" -- Use telescope as picker
vim.g.lazyvim_blink_main = true -- Use blink.cmp as main completion
vim.g.autoformat = true -- Enable auto-formatting
vim.g.deprecation_warnings = false -- Disable deprecation warnings

-- Better root detection
vim.g.root_spec = { "lsp", { ".git", "lua" }, "cwd" }

-- AI completion preferences
vim.g.ai_cmp = true -- Enable AI completion

-- Disable some built-in plugins for better performance
vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1
