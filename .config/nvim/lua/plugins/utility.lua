-- lua/plugins/utility.lua
return {
  -- Commenting (gcc, gbc, etc.)
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    config = function()
      require("Comment").setup()
    end,
  },

  -- Surround motions (ysiw", ds", cs"' etc.)
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = true },
    },
  },

  -- Auto save
  {
    "pocco81/auto-save.nvim",
    event = "InsertLeave",
    config = function()
      require("auto-save").setup({
        debounce_delay = 135,
        execution_message = {
          enabled = false,
        },
      })
    end,
  },

  -- Session management
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", [[<cmd>lua require("persistence").load()<cr>]], desc = "Restore Session" },
      { "<leader>ql", [[<cmd>lua require("persistence").load({ last = true })<cr>]], desc = "Restore Last Session" },
      { "<leader>qd", [[<cmd>lua require("persistence").stop()<cr>]], desc = "Don't Save Current Session" },
    },
  },

  -- Undo tree visualizer
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<CR>", desc = "Toggle Undotree" },
    },
  },

  -- Better escape from insert mode
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup({
        mapping = { "jk", "jj" },
        timeout = 300,
      })
    end,
  },

  -- Filetype icons (optional, for prettier lists)
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
}
