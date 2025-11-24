return {
  {
    "kristijanhusak/vim-dadbod-ui",
    init = function()
      -- Define your databases here.
      -- The UI will automatically load these; no need to 'Add Connection' manually.
      vim.g.dbs = {
        {
          name = "Jam (MySQL)",
          -- Construct the URL using Lua's os.getenv()
          url = "mysql://"
            .. (os.getenv("JAM_USER") or "admin")
            .. ":"
            .. (os.getenv("JAM_PASS_ENCODED") or "")
            .. "@"
            .. (os.getenv("JAM_HOST") or "localhost:3306"),
          -- .. "/test", -- Replace 'jam_db_name' with your actual DB name
        },
        -- Your Oracle ADB (Pantry)
        {
          name = "Pantry (Oracle ADB)",
          -- The syntax is oracle://user:pass@TNS_ALIAS
          url = "oracle://"
            .. (os.getenv("PANTRY_USER") or "ADMIN")
            .. ":"
            .. (os.getenv("PANTRY_PASS") or "")
            .. "@pantry_high/test",
          -- You can change @pantry_high to @pantry_low or @pantry_medium
          -- based on your performance needs defined in tnsnames.ora
        },
      }
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },
}
