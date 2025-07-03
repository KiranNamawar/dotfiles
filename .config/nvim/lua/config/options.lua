-- lua/config/options.lua
-- These options are loaded before LazyVim starts

-- Enable Windows clipboard integration when running in WSL
vim.g.clipboard = {
  name = "WSLClipboard",
  copy = {
    ["+"] = "clip.exe",
    ["*"] = "clip.exe",
  },
  paste = {
    ["+"] = "powershell.exe -NoProfile -Command Get-Clipboard",
    ["*"] = "powershell.exe -NoProfile -Command Get-Clipboard",
  },
  cache_enabled = true,
}

-- Customize Copilot suggestion color
vim.api.nvim_set_hl(0, "CopilotSuggestion", {
  fg = "#50fa7b",
  italic = true,
})

-- lua/config/options.lua
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.splitright = true
vim.opt.splitbelow = true
