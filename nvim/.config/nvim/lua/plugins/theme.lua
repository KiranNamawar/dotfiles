return {
  -- 1. Install the theme plugin
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false, -- load at start
    priority = 1000, -- load first
  },

  -- 2. Tell LazyVim to use this colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "github_dark_default",
    },
  },
}
