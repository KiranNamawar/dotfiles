return {
  "okuuva/auto-save.nvim",
  event = { "InsertLeave", "TextChanged" },
  keys = {
    { "<leader>uv", "md>ASToggle<CR>", desc = "Toggle autosave" },
  },
}
