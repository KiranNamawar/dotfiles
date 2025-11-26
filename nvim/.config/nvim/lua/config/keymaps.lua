-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- "Select Database" for the current buffer
vim.keymap.set("n", "<leader>D", "<cmd>DBUIFindBuffer<cr>", { desc = "Select DB for Buffer" })

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Insert-mode cursor movement
map("i", "<A-h>", "<C-o>0", opts) -- beginning of line
map("i", "<A-l>", "<C-o>$", opts) -- end of line
