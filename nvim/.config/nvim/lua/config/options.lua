-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Stop cluttering my cloud drive with backup files
vim.opt.backup = false -- disable backup files (filename~)
vim.opt.writebackup = false -- disable write backup

-- use sqlcl for oracle DB
vim.g.db_adapter_oracle_bin = "sql"
