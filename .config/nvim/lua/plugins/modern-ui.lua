-- lua/plugins/modern-ui.lua
-- Modern UI components following the Ultimate Dotfiles Enhancement Plan

return {
  -- Modern Statusline - Replace lualine with mini.statusline
  {
    "echasnovski/mini.statusline",
    version = false,
    event = "VeryLazy",
    config = function()
      local statusline = require("mini.statusline")
      
      -- Custom function to show Copilot status
      local function copilot_status()
        local ok, api = pcall(require, "copilot.api")
        if not ok or not api.status then
          return ""
        end

        local status = api.status.data
        if not status then
          return ""
        end

        local icon = "󰚩" -- Copilot icon
        if status.status == "Normal" then
          return icon .. " On"
        elseif status.status == "InProgress" then
          return icon .. " ..."
        elseif status.status == "Disabled" then
          return icon .. " Off"
        else
          return icon .. " " .. status.status
        end
      end

      -- Custom content function
      local function custom_content()
        local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
        local git = statusline.section_git({ trunc_width = 75 })
        local diagnostics = statusline.section_diagnostics({ trunc_width = 75 })
        local filename = statusline.section_filename({ trunc_width = 140 })
        local fileinfo = statusline.section_fileinfo({ trunc_width = 120 })
        local location = statusline.section_location({ trunc_width = 75 })
        local search = statusline.section_searchcount({ trunc_width = 75 })
        local copilot = copilot_status()

        return statusline.combine_groups({
          { hl = mode_hl, strings = { mode } },
          { hl = "MiniStatuslineDevinfo", strings = { git, diagnostics } },
          "%<", -- Mark general truncate point
          { hl = "MiniStatuslineFilename", strings = { filename } },
          "%=", -- End left alignment
          { hl = "MiniStatuslineFileinfo", strings = { copilot, fileinfo, search, location } },
        })
      end

      statusline.setup({
        content = {
          active = custom_content,
          inactive = function()
            return statusline.combine_groups({
              { hl = "MiniStatuslineInactive", strings = { statusline.section_filename() } },
            })
          end,
        },
        use_icons = vim.g.have_nerd_font ~= false,
        set_vim_settings = false,
      })
    end,
  },

  -- Modern Dashboard - Snacks.nvim for startup screen
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = {
        enabled = true,
        preset = {
          header = [[
██╗██████╗ ██████╗ ███████╗███████╗██╗███████╗████████╗██╗██████╗ ██╗     ███████╗
██║██╔══██╗██╔══██╗██╔════╝██╔════╝██║██╔════╝╚══██╔══╝██║██╔══██╗██║     ██╔════╝
██║██████╔╝██████╔╝█████╗  ███████╗██║███████╗   ██║   ██║██████╔╝██║     █████╗  
██║██╔══██╗██╔══██╗██╔══╝  ╚════██║██║╚════██║   ██║   ██║██╔══██╗██║     ██╔══╝  
██║██║  ██║██║  ██║███████╗███████║██║███████║   ██║   ██║██████╔╝███████╗███████╗
╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚══════╝   ╚═╝   ╚═╝╚═════╝ ╚══════╝╚══════╝
                                                                                    
        ⚡ Ultimate Terminal Experience ⚡                                          
          ]],
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },

  -- Enhanced Search and Navigation - Flash.nvim
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      search = {
        multi_window = true,
        forward = true,
        wrap = true,
        incremental = false,
      },
      jump = {
        jumplist = true,
        pos = "start",
        history = false,
        register = false,
        nohlsearch = false,
        autojump = false,
      },
      label = {
        uppercase = true,
        exclude = "",
        current = true,
        after = true,
        before = false,
        style = "overlay",
        reuse = "lowercase",
        distance = true,
        min_pattern_length = 0,
        rainbow = {
          enabled = false,
          shade = 5,
        },
      },
      highlight = {
        backdrop = true,
        matches = true,
        priority = 5000,
        groups = {
          match = "FlashMatch",
          current = "FlashCurrent",
          backdrop = "FlashBackdrop",
          label = "FlashLabel",
        },
      },
      modes = {
        search = {
          enabled = true,
          highlight = { backdrop = false },
          jump = { history = true, register = true, nohlsearch = true },
          search = {
            mode = "search",
            max_length = false,
          },
        },
        char = {
          enabled = true,
          config = function(opts)
            opts.autohide = opts.autohide == nil and (vim.fn.mode(true):find("no") and vim.v.operator == "y")
            opts.jump_labels = opts.jump_labels
              and vim.v.count == 0
              and vim.fn.reg_executing() == ""
              and vim.fn.reg_recording() == ""
          end,
          autohide = false,
          jump_labels = false,
          multi_line = true,
          label = { exclude = "hjkliardc" },
          keys = { "f", "F", "t", "T", ";", "," },
          char_actions = function(motion)
            return {
              [";"] = "next", -- set to `right` to always go right
              [","] = "prev", -- set to `left` to always go left
              [motion:lower()] = "next",
              [motion:upper()] = "prev",
            }
          end,
          search = { wrap = false },
          highlight = { backdrop = true },
          jump = { register = false },
        },
        treesitter = {
          labels = "abcdefghijklmnopqrstuvwxyz",
          jump = { pos = "range" },
          search = { incremental = false },
          label = { before = true, after = true, style = "inline" },
          highlight = {
            backdrop = false,
            matches = false,
          },
        },
        treesitter_search = {
          jump = { pos = "range" },
          search = { multi_window = true, wrap = true, incremental = false },
          remote_op = { restore = true },
          label = { before = true, after = true, style = "inline" },
        },
        remote = {
          remote_op = { restore = true, motion = true },
        },
      },
      prompt = {
        enabled = true,
        prefix = { { "⚡", "FlashPromptIcon" } },
        win_config = {
          relative = "editor",
          width = 1,
          height = 1,
          row = -1,
          col = 0,
          zindex = 1000,
        },
      },
      remote_op = {
        restore = false,
        motion = false,
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- Disable old lualine configuration when using mini.statusline
  {
    "nvim-lualine/lualine.nvim",
    enabled = false,
  },

  -- Alternative: Keep incline for winbar if desired
  {
    "b0o/incline.nvim",
    event = "VeryLazy",
    enabled = true,
    config = function()
      local helpers = require("incline.helpers")
      local devicons = require("nvim-web-devicons")
      
      require("incline").setup({
        window = {
          padding = 0,
          margin = { horizontal = 0, vertical = 0 },
        },
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
          if filename == "" then
            filename = "[No Name]"
          end
          
          local ft_icon, ft_color = devicons.get_icon_color(filename)
          local modified = vim.bo[props.buf].modified
          
          return {
            ft_icon and { " ", ft_icon, " ", guifg = ft_color } or "",
            " ",
            { filename, gui = modified and "bold,italic" or "bold" },
            " ",
            guibg = "#363a4f", -- Catppuccin surface0
          }
        end,
      })
    end,
  },
}
