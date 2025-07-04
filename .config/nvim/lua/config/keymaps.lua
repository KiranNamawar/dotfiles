-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    if opts.remap and not vim.g.vscode then
      opts.remap = nil
    end
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- ============================================================================
-- BETTER DEFAULTS
-- ============================================================================

-- Better escape sequences
map("i", "jk", "<ESC>", { desc = "Exit insert mode" })
map("i", "kj", "<ESC>", { desc = "Exit insert mode" })

-- Better navigation
map("n", "j", "gj", { desc = "Move down (wrapped lines)" })
map("n", "k", "gk", { desc = "Move up (wrapped lines)" })
map("n", "<Down>", "gj", { desc = "Move down (wrapped lines)" })
map("n", "<Up>", "gk", { desc = "Move up (wrapped lines)" })

-- Better indenting
map("v", "<", "<gv", { desc = "Indent left and reselect" })
map("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Better line manipulation
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Better search
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })
map("n", "*", "*zzzv", { desc = "Search word under cursor (centered)" })
map("n", "#", "#zzzv", { desc = "Search word under cursor backwards (centered)" })
map("n", "g*", "g*zzzv", { desc = "Search word under cursor (partial, centered)" })
map("n", "g#", "g#zzzv", { desc = "Search word under cursor backwards (partial, centered)" })

-- Better joins
map("n", "J", "mzJ`z", { desc = "Join lines (keep cursor position)" })

-- Better undo breakpoints
map("i", ",", ",<c-g>u", { desc = "Comma with undo breakpoint" })
map("i", ".", ".<c-g>u", { desc = "Period with undo breakpoint" })
map("i", "!", "!<c-g>u", { desc = "Exclamation with undo breakpoint" })
map("i", "?", "?<c-g>u", { desc = "Question with undo breakpoint" })

-- ============================================================================
-- WINDOW MANAGEMENT
-- ============================================================================

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Window resizing
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Window management
map("n", "<leader>ww", "<C-W>p", { desc = "Other window" })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete window" })
map("n", "<leader>w-", "<C-W>s", { desc = "Split window below" })
map("n", "<leader>w|", "<C-W>v", { desc = "Split window right" })
map("n", "<leader>w=", "<C-W>=", { desc = "Balance windows" })

-- ============================================================================
-- BUFFER MANAGEMENT
-- ============================================================================

-- Better buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Buffer management
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<leader>bD", "<cmd>bdelete!<cr>", { desc = "Delete buffer (force)" })

-- ============================================================================
-- QUICKFIX AND LOCATION LIST
-- ============================================================================

-- Better quickfix navigation
map("n", "<leader>qo", "<cmd>copen<cr>", { desc = "Open quickfix" })
map("n", "<leader>qc", "<cmd>cclose<cr>", { desc = "Close quickfix" })
map("n", "<leader>qn", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
map("n", "<leader>qp", "<cmd>cprevious<cr>", { desc = "Previous quickfix item" })

-- Location list
map("n", "<leader>lo", "<cmd>lopen<cr>", { desc = "Open location list" })
map("n", "<leader>lc", "<cmd>lclose<cr>", { desc = "Close location list" })
map("n", "<leader>ln", "<cmd>lnext<cr>", { desc = "Next location item" })
map("n", "<leader>lp", "<cmd>lprevious<cr>", { desc = "Previous location item" })

-- ============================================================================
-- EDITING ENHANCEMENTS
-- ============================================================================

-- Better paste
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- Better delete
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- System clipboard
map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard" })

-- WSL-specific clipboard integration
if vim.fn.has("wsl") == 1 then
  map("n", "<leader>wy", "<cmd>%y+<cr>", { desc = "Copy entire buffer to Windows clipboard" })
  map("v", "<leader>wy", [["+y]], { desc = "Copy selection to Windows clipboard" })
end

-- Add empty lines
map("n", "<leader>o", "o<esc>", { desc = "Add empty line below" })
map("n", "<leader>O", "O<esc>", { desc = "Add empty line above" })

-- Better substitution
map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Substitute word under cursor" })
map("x", "<leader>s", [[:s/\V<C-R>=escape(@", '/\')<CR>/<C-R>=escape(@", '/\')<CR>/gI<Left><Left><Left>]], { desc = "Substitute selection" })

-- ============================================================================
-- TOGGLE UTILITIES
-- ============================================================================

-- Toggle options
map("n", "<leader>tw", "<cmd>set wrap!<cr>", { desc = "Toggle word wrap" })
map("n", "<leader>ts", "<cmd>set spell!<cr>", { desc = "Toggle spell check" })
map("n", "<leader>tn", "<cmd>set number!<cr>", { desc = "Toggle line numbers" })
map("n", "<leader>tr", "<cmd>set relativenumber!<cr>", { desc = "Toggle relative numbers" })
map("n", "<leader>tl", "<cmd>set list!<cr>", { desc = "Toggle list chars" })
map("n", "<leader>tc", "<cmd>set cursorline!<cr>", { desc = "Toggle cursor line" })
map("n", "<leader>tC", "<cmd>set cursorcolumn!<cr>", { desc = "Toggle cursor column" })

-- Toggle fold
map("n", "<leader>tf", "<cmd>set foldenable!<cr>", { desc = "Toggle folding" })

-- ============================================================================
-- DEVELOPMENT UTILITIES
-- ============================================================================

-- Source current file
map("n", "<leader><leader>", function()
  if vim.bo.filetype == "lua" then
    vim.cmd("source %")
    vim.notify("File sourced!", vim.log.levels.INFO)
  else
    vim.notify("Not a Lua file!", vim.log.levels.WARN)
  end
end, { desc = "Source current file (Lua)" })

-- Execute current line/selection
map("n", "<leader>xx", "<cmd>.lua<cr>", { desc = "Execute current line (Lua)" })
map("v", "<leader>xx", "<cmd>lua<cr>", { desc = "Execute selection (Lua)" })

-- Make file executable
map("n", "<leader>fx", "<cmd>!chmod +x %<cr>", { desc = "Make file executable", silent = true })

-- ============================================================================
-- DIAGNOSTIC NAVIGATION
-- ============================================================================

-- Better diagnostic navigation
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]e", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Next error" })
map("n", "[e", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Previous error" })
map("n", "]w", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN }) end, { desc = "Next warning" })
map("n", "[w", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN }) end, { desc = "Previous warning" })

-- ============================================================================
-- COMMAND LINE ENHANCEMENTS
-- ============================================================================

-- Better command line navigation
map("c", "<C-j>", "<Down>", { desc = "Next command" })
map("c", "<C-k>", "<Up>", { desc = "Previous command" })
map("c", "<C-h>", "<Left>", { desc = "Move left" })
map("c", "<C-l>", "<Right>", { desc = "Move right" })
map("c", "<C-a>", "<Home>", { desc = "Move to beginning" })
map("c", "<C-e>", "<End>", { desc = "Move to end" })

-- ============================================================================
-- TERMINAL ENHANCEMENTS
-- ============================================================================

-- Better terminal navigation
map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Go to left window" })
map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Go to lower window" })
map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Go to upper window" })
map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Go to right window" })
map("t", "<C-/>", "<cmd>close<cr>", { desc = "Hide terminal" })
map("t", "<c-_>", "<cmd>close<cr>", { desc = "Hide terminal (which-key)" })

-- Terminal escape
map("t", "<C-q>", "<C-\\><C-n>", { desc = "Enter normal mode" })

-- ============================================================================
-- MISCELLANEOUS
-- ============================================================================

-- Clear search highlighting
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlighting" })

-- Better macro replay
map("n", "Q", "@@", { desc = "Replay last macro" })

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 300 })
  end,
})

-- Save with Ctrl+S
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- Quit with Ctrl+Q
map("n", "<C-q>", "<cmd>qa<cr>", { desc = "Quit all" })

-- Better page navigation
map("n", "<C-d>", "<C-d>zz", { desc = "Page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Page up (centered)" })

-- URL handling
map("n", "gx", function()
  local url = vim.fn.expand("<cfile>")
  if url then
    vim.fn.system("xdg-open " .. url)
  end
end, { desc = "Open URL under cursor" })
