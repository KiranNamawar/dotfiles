-- lua/config/autocmds.lua

-- Default LazyVim autocmds are loaded automatically with the VeryLazy event.
-- You can add or override your own below.

local api = vim.api
local augroup = api.nvim_create_augroup
local autocmd = api.nvim_create_autocmd

-- General autocommands group
local general = augroup("custom_autocmds", { clear = true })

-- Highlight on yank
autocmd("TextYankPost", {
  group = general,
  desc = "Highlight selection on yank",
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
autocmd("BufWritePre", {
  group = general,
  desc = "Trim trailing whitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

-- Resize splits if window is resized
autocmd("VimResized", {
  group = general,
  desc = "Auto resize splits on window resize",
  command = "tabdo wincmd =",
})

-- Enable spell checking for markdown and git commit messages
autocmd("FileType", {
  group = general,
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.wrap = true
  end,
})
