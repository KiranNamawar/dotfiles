-- lua/plugins/treesitter.lua
return {
  -- Treesitter Core
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "windwp/nvim-ts-autotag",
      "nvim-treesitter/nvim-treesitter-context",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua",
          "vim",
          "vimdoc",
          "javascript",
          "typescript",
          "html",
          "css",
          "json",
          "go",
        },
        sync_install = false,
        auto_install = true,
        ignore_install = {},
        modules = {},

        highlight = { enable = true },
        indent = { enable = true },
        autotag = { enable = true },
        context_commentstring = {
          enable = true,
          enable_autocmd = false,
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
        },
      })
    end,
  },

  -- HTML/XML auto close & rename
  {
    "windwp/nvim-ts-autotag",
    ft = { "html", "javascriptreact", "typescriptreact", "svelte", "vue", "xml" },
    config = true,
  },

  -- Sticky header for context
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPre",
    opts = {},
  },
}
