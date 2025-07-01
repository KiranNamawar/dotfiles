-- lua/plugins/diagnostics.lua
return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Set up diagnostic display behavior
      vim.diagnostic.config({
        virtual_text = {
          spacing = 4,
          prefix = "●", -- symbol shown before diagnostic text
          source = true, -- must be boolean in recent Neovim
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = true, -- this is valid for floating windows
        },
      })

      -- Optional: Custom diagnostic sign icons in the gutter
      local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end
    end,
  },
}
