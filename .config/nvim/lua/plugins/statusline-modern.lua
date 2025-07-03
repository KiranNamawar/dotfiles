-- Modern statusline configuration using mini.statusline
-- Replaces lualine for better performance and simpler config

return {
  -- Disable lualine in favor of mini.statusline
  {
    "nvim-lualine/lualine.nvim",
    enabled = false,
  },
  
  -- Modern lightweight statusline
  {
    "echasnovski/mini.statusline",
    version = false,
    event = "VeryLazy",
    config = function()
      local statusline = require("mini.statusline")
      
      -- Custom content function for enhanced statusline
      local function my_statusline()
        local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
        local git = statusline.section_git({ trunc_width = 40 })
        local diff = statusline.section_diff({ trunc_width = 75 })
        local diagnostics = statusline.section_lsp({ trunc_width = 75 })
        local lsp = statusline.section_lsp({ trunc_width = 75 })
        local filename = statusline.section_filename({ trunc_width = 140 })
        local fileinfo = statusline.section_fileinfo({ trunc_width = 120 })
        local location = statusline.section_location({ trunc_width = 75 })
        local search = statusline.section_searchcount({ trunc_width = 75 })
        
        -- Custom Copilot status
        local function copilot_status()
          local ok, api = pcall(require, "copilot.api")
          if not ok or not api.status then
            return ""
          end
          
          local status = api.status.data
          if not status then
            return ""
          end
          
          local icon = " "
          if status.status == "Normal" then
            return "%#MiniStatuslineModeInsert#" .. icon .. "On%*"
          elseif status.status == "InProgress" then
            return "%#MiniStatuslineModeCommand#" .. icon .. "...%*"
          elseif status.status == "Disabled" then
            return "%#MiniStatuslineModeOther#" .. icon .. "Off%*"
          else
            return "%#MiniStatuslineModeOther#" .. icon .. status.status .. "%*"
          end
        end
        
        local copilot = copilot_status()
        
        return statusline.combine_groups({
          { hl = mode_hl, strings = { mode } },
          { hl = "MiniStatuslineDevinfo", strings = { git, diff, diagnostics } },
          "%<", -- Mark general truncate point
          { hl = "MiniStatuslineFilename", strings = { filename } },
          "%=", -- End left alignment
          { hl = "MiniStatuslineFileinfo", strings = { fileinfo, copilot } },
          { hl = mode_hl, strings = { search, location } },
        })
      end
      
      statusline.setup({
        content = {
          active = my_statusline,
        },
        use_icons = true,
        set_vim_settings = false, -- Don't override existing statusline settings
      })
    end,
  },
}
