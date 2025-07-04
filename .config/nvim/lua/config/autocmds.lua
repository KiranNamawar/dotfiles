-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- ============================================================================
-- EDITING ENHANCEMENTS
-- ============================================================================

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 300 })
  end,
})

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("remove_trailing_whitespace", { clear = true }),
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end,
})

-- Auto create directories when saving files
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("auto_create_dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- ============================================================================
-- BUFFER MANAGEMENT
-- ============================================================================

-- Close certain filetypes with 'q'
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("close_with_q", { clear = true }),
  pattern = {
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "query",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
    "dbout",
    "gitsigns.blame",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Don't auto-comment new lines
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("no_auto_comment", { clear = true }),
  callback = function()
    vim.opt.formatoptions:remove({ "c", "r", "o" })
  end,
})

-- ============================================================================
-- WINDOW MANAGEMENT
-- ============================================================================

-- Resize splits if window got resized
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("resize_splits", { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Go to last location when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("last_loc", { clear = true }),
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ============================================================================
-- FILETYPE SPECIFIC
-- ============================================================================

-- Set wrap and spell for text files
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("wrap_spell", { clear = true }),
  pattern = { "gitcommit", "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Set specific settings for different filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("filetype_settings", { clear = true }),
  callback = function()
    local ft = vim.bo.filetype
    
    -- JSON files
    if ft == "json" then
      vim.opt_local.conceallevel = 0
    end
    
    -- Help files
    if ft == "help" then
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
    end
    
    -- Terminal
    if ft == "terminal" then
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = "no"
    end
    
    -- Lua files
    if ft == "lua" then
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
    end
    
    -- Python files
    if ft == "python" then
      vim.opt_local.shiftwidth = 4
      vim.opt_local.tabstop = 4
    end
    
    -- Go files
    if ft == "go" then
      vim.opt_local.expandtab = false
      vim.opt_local.shiftwidth = 4
      vim.opt_local.tabstop = 4
    end
  end,
})

-- ============================================================================
-- PERFORMANCE OPTIMIZATIONS
-- ============================================================================

-- Disable syntax highlighting for large files
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("large_file_optimizations", { clear = true }),
  callback = function()
    local line_count = vim.api.nvim_buf_line_count(0)
    if line_count > 5000 then
      vim.cmd("syntax off")
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.spell = false
      vim.notify("Large file detected, disabled syntax highlighting", vim.log.levels.INFO)
    end
  end,
})

-- ============================================================================
-- WSL OPTIMIZATIONS
-- ============================================================================

if vim.fn.has("wsl") == 1 then
  -- Optimize file watching for WSL
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("wsl_file_watch", { clear = true }),
    callback = function()
      vim.opt_local.backup = false
      vim.opt_local.writebackup = false
      vim.opt_local.swapfile = false
    end,
  })
end

-- ============================================================================
-- DEVELOPMENT HELPERS
-- ============================================================================

-- Auto-reload configuration files
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("auto_reload_config", { clear = true }),
  pattern = { "*.lua" },
  callback = function()
    local filepath = vim.fn.expand("%:p")
    if filepath:match("config/nvim") and not filepath:match("lazy-lock.json") then
      vim.defer_fn(function()
        vim.cmd("source " .. filepath)
        vim.notify("Configuration reloaded: " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
      end, 100)
    end
  end,
})

-- Auto-format on save for specific filetypes
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("auto_format", { clear = true }),
  pattern = { "*.lua", "*.js", "*.ts", "*.jsx", "*.tsx", "*.json", "*.md", "*.py" },
  callback = function()
    if vim.g.autoformat then
      vim.lsp.buf.format({ async = false })
    end
  end,
})

-- Check if file changed outside of Neovim
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = vim.api.nvim_create_augroup("checktime", { clear = true }),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- ============================================================================
-- VISUAL ENHANCEMENTS
-- ============================================================================

-- Show cursor line only in active window
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
  group = vim.api.nvim_create_augroup("auto_cursorline", { clear = true }),
  callback = function()
    if vim.wo.cursorline then
      vim.wo.cursorline = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
  group = vim.api.nvim_create_augroup("auto_cursorline", { clear = false }),
  callback = function()
    if vim.wo.cursorline then
      vim.wo.cursorline = false
    end
  end,
})

-- ============================================================================
-- ERROR HANDLING
-- ============================================================================

-- Handle errors gracefully
vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("error_handler", { clear = true }),
  pattern = "LazyVimStarted",
  callback = function()
    -- Set up global error handler
    vim.o.errorformat = "%f:%l:%c: %t%*[^:]: %m,%f:%l: %t%*[^:]: %m"
    
    -- Better error display
    vim.diagnostic.config({
      virtual_text = { prefix = "●" },
      signs = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = {
        focusable = true,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    })
  end,
})
