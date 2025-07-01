-- Add any additional keymaps here
-- Loaded automatically on the VeryLazy event

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Save file
keymap("n", "<C-s>", ":w<CR>", vim.tbl_extend("force", opts, { desc = "Save File" }))

-- Close buffer
keymap("n", "<leader>q", ":bd<CR>", vim.tbl_extend("force", opts, { desc = "Close Buffer" }))

-- Move lines up/down
keymap("n", "<A-j>", ":m .+1<CR>==", vim.tbl_extend("force", opts, { desc = "Move Line Down" }))
keymap("n", "<A-k>", ":m .-2<CR>==", vim.tbl_extend("force", opts, { desc = "Move Line Up" }))

-- Clear search highlight
keymap("n", "<leader>h", ":nohlsearch<CR>", vim.tbl_extend("force", opts, { desc = "Clear Highlight" }))

-- Easier window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Open Lazy
keymap("n", "<leader>l", ":Lazy<CR>", vim.tbl_extend("force", opts, { desc = "Open Lazy" }))

-- LSP: Rename symbol
keymap("n", "<leader>rn", vim.lsp.buf.rename, { desc = "LSP Rename", silent = true })

-- LSP: Format file
keymap("n", "<leader>fm", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "LSP Format" })

-- Telescope quick access
keymap("n", "<leader><space>", "<cmd>Telescope find_files<CR>", { desc = "Find Files" })
