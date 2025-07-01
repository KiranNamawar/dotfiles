-- lua/plugins/colorscheme.lua
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = true,
      terminal_colors = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
      sidebars = {
        "qf",
        "help",
        "neo-tree",
        "terminal",
        "lazy",
        "packer",
        "spectre_panel",
        "Outline",
      },
    },
    config = function(_, opts)
      vim.opt.termguicolors = true
      require("tokyonight").setup(opts)
      local ok, _ = pcall(vim.cmd.colorscheme, "tokyonight")
      if not ok then
        vim.notify("Failed to load colorscheme 'tokyonight'", vim.log.levels.ERROR)
      end
    end,
  },
}
