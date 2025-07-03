-- lua/plugins/colorscheme.lua
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = true,
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      no_italic = false,
      no_bold = false,
      no_underline = false,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      color_overrides = {},
      custom_highlights = {},
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = false,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
        telescope = {
          enabled = true,
        },
        lsp_trouble = true,
        which_key = true,
      },
    },
    config = function(_, opts)
      vim.opt.termguicolors = true
      require("catppuccin").setup(opts)
      local ok, _ = pcall(vim.cmd.colorscheme, "catppuccin")
      if not ok then
        vim.notify("Failed to load colorscheme 'catppuccin'", vim.log.levels.ERROR)
      end
    end,
  },
  -- Alternative colorschemes as recommended in your plan
  {
    "rose-pine/neovim",
    name = "rose-pine",
    enabled = false, -- Disabled by default, enable if you want to try it
    opts = {
      variant = "auto", -- auto, main, moon, or dawn
      dark_variant = "main", -- main, moon, or dawn
      dim_inactive_windows = false,
      extend_background_behind_borders = true,
      styles = {
        bold = true,
        italic = true,
        transparency = true,
      },
    },
  },
  {
    "EdenEast/nightfox.nvim",
    enabled = false, -- Disabled by default
    opts = {
      options = {
        transparent = true,
        terminal_colors = true,
        dim_inactive = false,
        styles = {
          comments = "italic",
          conditionals = "NONE",
          constants = "NONE",
          functions = "NONE",
          keywords = "NONE",
          numbers = "NONE",
          operators = "NONE",
          strings = "NONE",
          types = "NONE",
          variables = "NONE",
        },
      },
    },
  },
}
