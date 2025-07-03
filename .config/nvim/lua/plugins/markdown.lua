-- lua/plugins/markdown.lua
return {
  -- HEADERS and formatting: underline, bullets, etc.
  {
    "lukas-reineke/headlines.nvim",
    dependencies = "nvim-treesitter/nvim-treesitter",
    ft = { "markdown" },
    opts = {},
  },

  -- Smart motions, links, Zettelkasten support
  {
    "jakewvincent/mkdnflow.nvim",
    ft = "markdown",
    config = function()
      require("mkdnflow").setup({
        modules = {
          maps = true,
          links = true,
          tables = true,
          yaml = true,
        },
      })
    end,
  },

  -- Terminal-based preview with Glow
  {
    "ellisonleao/glow.nvim",
    cmd = "Glow",
    config = true,
    keys = {
      { "<leader>mg", "<cmd>Glow<CR>", desc = "Markdown Glow Preview" },
    },
  },

  -- Treesitter context lines (for Markdown and more)
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPre",
    opts = {
      mode = "cursor",
      max_lines = 5,
    },
  },

  -- Markdown-specific editor settings
  {
    "nvim-lua/plenary.nvim",
    event = "BufReadPre",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          vim.opt_local.spell = true
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.breakindent = true
          vim.opt_local.breakindentopt = "shift:2"
        end,
      })
    end,
  },
}
