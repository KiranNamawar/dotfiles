-- ============================================================================
-- COLORSCHEME CONFIGURATION
-- ============================================================================
-- Modern, beautiful colorschemes with proper WSL support and LazyVim integration

return {
  -- Catppuccin - Modern, elegant colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = false,
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = true,
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
      custom_highlights = function(colors)
        return {
          -- Enhanced cursor line
          CursorLine = { bg = colors.surface0 },
          CursorColumn = { bg = colors.surface0 },
          
          -- Better search highlighting
          Search = { bg = colors.yellow, fg = colors.base },
          IncSearch = { bg = colors.red, fg = colors.base },
          
          -- Enhanced diff colors
          DiffAdd = { bg = colors.green, fg = colors.base },
          DiffChange = { bg = colors.yellow, fg = colors.base },
          DiffDelete = { bg = colors.red, fg = colors.base },
          DiffText = { bg = colors.blue, fg = colors.base },
          
          -- Better completion menu
          Pmenu = { bg = colors.surface0, fg = colors.text },
          PmenuSel = { bg = colors.blue, fg = colors.base },
          PmenuSbar = { bg = colors.surface1 },
          PmenuThumb = { bg = colors.blue },
          
          -- Enhanced diagnostic colors
          DiagnosticError = { fg = colors.red },
          DiagnosticWarn = { fg = colors.yellow },
          DiagnosticInfo = { fg = colors.blue },
          DiagnosticHint = { fg = colors.teal },
          
          -- Better fold colors
          Folded = { bg = colors.surface0, fg = colors.overlay1 },
          FoldColumn = { bg = colors.base, fg = colors.overlay1 },
          
          -- WSL-specific optimizations
          Normal = { bg = colors.base, fg = colors.text },
          NormalFloat = { bg = colors.mantle, fg = colors.text },
          FloatBorder = { bg = colors.mantle, fg = colors.blue },
        }
      end,
      integrations = {
        cmp = false, -- Using blink.cmp instead
        blink_cmp = true,
        gitsigns = true,
        nvimtree = false,
        neotree = true,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "lavender",
        },
        aerial = true,
        alpha = true,
        dashboard = true,
        flash = true,
        leap = true,
        markdown = true,
        mason = true,
        neotest = true,
        noice = true,
        telescope = {
          enabled = true,
          style = "nvchad",
        },
        treesitter_context = true,
        which_key = true,
        dap = true,
        dap_ui = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints = {
            background = true,
          },
        },
        barbecue = {
          dim_dirname = true,
          bold_basename = true,
          dim_context = false,
          alt_background = false,
        },
        fern = false,
        gitgutter = false,
        hop = false,
        indent_blankline = {
          enabled = true,
          scope_color = "lavender",
          colored_indent_levels = false,
        },
        lightspeed = false,
        lsp_saga = false,
        lsp_trouble = true,
        navic = {
          enabled = false,
          custom_bg = "NONE",
        },
        octo = true,
        overseer = true,
        pounce = false,
        sandwich = false,
        semantic_tokens = true,
        symbols_outline = true,
        telekasten = true,
        ts_rainbow = false,
        ts_rainbow2 = false,
        vim_sneak = false,
        vimwiki = true,
        dropbar = {
          enabled = true,
          color_mode = true,
        },
      },
    },
  },

  -- Tokyo Night - Another excellent modern colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night", -- storm, moon, night, day
      light_style = "day",
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
        sidebars = "dark",
        floats = "dark",
      },
      sidebars = { "qf", "help", "terminal", "packer" },
      day_brightness = 0.3,
      hide_inactive_statusline = false,
      dim_inactive = true,
      lualine_bold = false,
      
      -- Custom colors and highlights
      on_colors = function(colors)
        colors.hint = colors.orange
        colors.error = "#ff0000"
      end,
      on_highlights = function(highlights, colors)
        highlights.TSKeyword = { fg = colors.purple, style = { italic = true } }
        highlights.TSComment = { fg = colors.comment, style = { italic = true } }
      end,
    },
  },

  -- Rose Pine - Elegant and minimal
  {
    "rose-pine/neovim",
    name = "rose-pine",
    opts = {
      variant = "auto", -- auto, main, moon, or dawn
      dark_variant = "main",
      dim_inactive_windows = false,
      extend_background_behind_borders = true,
      enable = {
        terminal = true,
        legacy_highlights = true,
        migrations = true,
      },
      styles = {
        bold = true,
        italic = true,
        transparency = false,
      },
      groups = {
        border = "muted",
        link = "iris",
        panel = "surface",
        error = "love",
        hint = "iris",
        info = "foam",
        note = "pine",
        todo = "rose",
        warn = "gold",
        git_add = "foam",
        git_change = "rose",
        git_delete = "love",
        git_dirty = "rose",
        git_ignore = "muted",
        git_merge = "iris",
        git_rename = "pine",
        git_stage = "iris",
        git_text = "rose",
        git_untracked = "subtle",
        headings = {
          h1 = "iris",
          h2 = "foam",
          h3 = "rose",
          h4 = "gold",
          h5 = "pine",
          h6 = "foam",
        },
      },
      highlight_groups = {
        ColorColumn = { bg = "rose" },
        CursorLine = { bg = "foam", blend = 10 },
        StatusLine = { fg = "love", bg = "love", blend = 10 },
        Search = { bg = "gold", inherit = false },
        TelescopeBorder = { fg = "highlight_high", bg = "none" },
        TelescopeNormal = { bg = "none" },
        TelescopePromptNormal = { bg = "base" },
        TelescopeResultsNormal = { fg = "subtle", bg = "none" },
        TelescopeSelection = { fg = "text", bg = "base" },
        TelescopeSelectionCaret = { fg = "rose", bg = "rose" },
      },
      before_highlight = function(group, highlight, palette)
        -- Disable all undercurls
        if highlight.undercurl then
          highlight.undercurl = false
        end
      end,
    },
  },

  -- Gruvbox - Classic and reliable
  {
    "ellisonleao/gruvbox.nvim",
    opts = {
      terminal_colors = true,
      undercurl = true,
      underline = true,
      bold = true,
      italic = {
        strings = true,
        emphasis = true,
        comments = true,
        operators = false,
        folds = true,
      },
      strikethrough = true,
      invert_selection = false,
      invert_signs = false,
      invert_tabline = false,
      invert_intend_guides = false,
      inverse = true,
      contrast = "medium", -- hard, medium, soft
      palette_overrides = {},
      overrides = {},
      dim_inactive = false,
      transparent_mode = false,
    },
  },

  -- Configure LazyVim to use Catppuccin as default
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },

  -- Additional UI enhancements
  {
    "folke/drop.nvim",
    event = "VimEnter",
    opts = {
      theme = "snow", -- Can be "snow", "stars", "xmas", "spring", "summer"
      max = 40,
      interval = 150,
      screensaver = 1000 * 60 * 5, -- 5 minutes
      filetypes = { "dashboard", "alpha", "starter" },
    },
  },

  -- Highlight colors in files
  {
    "brenoprata10/nvim-highlight-colors",
    event = "BufReadPre",
    opts = {
      render = "background", -- 'background', 'foreground', 'virtual'
      enable_named_colors = true,
      enable_tailwind = true,
      custom_colors = {
        { label = "%-%-theme%-primary%-color", color = "#0f1419" },
        { label = "%-%-theme%-secondary%-color", color = "#5a5a5a" },
      },
    },
  },
}
