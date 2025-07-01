return {
  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "tokyonight",
        section_separators = "",
        component_separators = "",
        globalstatus = true,
      },
      sections = {
        lualine_x = {
          function()
            local ok, api = pcall(require, "copilot.api")
            if not ok or not api.status then
              return ""
            end

            local status = api.status.data
            if not status then
              return ""
            end

            local icon = " " -- Copilot icon
            if status.status == "Normal" then
              return icon .. "On"
            elseif status.status == "InProgress" then
              return icon .. "..."
            elseif status.status == "Disabled" then
              return icon .. "Off"
            else
              return icon .. status.status
            end
          end,
        },
      },
    },
  },

  -- Winbar / Tabline per buffer
  {
    "b0o/incline.nvim",
    event = "VeryLazy",
    config = function()
      require("incline").setup({
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
          local modified = vim.bo[props.buf].modified and " ●" or ""
          return {
            { filename, group = "InclineFilename" },
            { modified, group = "DiagnosticWarn" },
          }
        end,
      })
    end,
  },

  -- Command line, messages, LSP notifications
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    opts = {
      lsp = {
        signature = { enabled = false },
        hover = { enabled = true },
        progress = { enabled = true },
      },
      views = {
        cmdline_popup = {
          position = { row = 5, col = "50%" },
          size = { width = 60, height = "auto" },
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
    },
  },

  -- Toast-style notifications
  {
    "rcarriga/nvim-notify",
    lazy = false,
    config = function()
      local notify = require("notify")
      notify.setup({
        timeout = 3000,
        stages = "fade",
        background_colour = "#1e1e2e",
      })
      vim.notify = notify
    end,
  },

  -- UI Select & Input
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Smooth animation
  {
    "echasnovski/mini.animate",
    version = false,
    event = "VeryLazy",
    config = function()
      require("mini.animate").setup({
        cursor = { enable = true },
        scroll = { enable = false }, -- disable scroll animation
        resize = { enable = true },
        open = { enable = true },
        close = { enable = true },
      })
    end,
  },

  -- Dashboard
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = true,
  },
}
