return {
  -- LSP UI: Lspsaga
  {
    "glepnir/lspsaga.nvim",
    event = "LspAttach",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lspsaga").setup({
        diagnostic = {
          show_code_action = true,
          show_source = true,
          jump_num_shortcut = true,
          keys = {
            exec_action = "o",
            quit = "q",
            go_action = "g",
            toggle_or_jump = "<CR>",
          },
        },
        ui = {
          border = "rounded",
          code_action = "",
          colors = {
            normal_bg = "#1e1e2e",
          },
        },
        symbol_in_winbar = {
          enable = true,
          separator = "  ",
          show_file = true,
        },
      })

      local keymap = vim.keymap.set
      local opts = { noremap = true, silent = true }

      keymap("n", "<leader>aa", "<cmd>Lspsaga code_action<CR>", vim.tbl_extend("force", opts, { desc = "Code Action" }))
      keymap(
        "v",
        "<leader>aa",
        ":<C-U>Lspsaga range_code_action<CR>",
        vim.tbl_extend("force", opts, { desc = "Range Code Action" })
      )
      keymap("n", "<leader>cd", "<cmd>Lspsaga show_line_diagnostics<CR>", { desc = "Line Diagnostics" })
      keymap("n", "[e", "<cmd>Lspsaga diagnostic_jump_prev<CR>", { desc = "Prev Diagnostic" })
      keymap("n", "]e", "<cmd>Lspsaga diagnostic_jump_next<CR>", { desc = "Next Diagnostic" })
    end,
  },

  { "smjonas/inc-rename.nvim", config = true },

  {
    "simrat39/inlay-hints.nvim",
    config = function()
      require("inlay-hints").setup()
    end,
  },

  -- Outline view
  {
    "hedyhli/outline.nvim",
    cmd = "Outline",
    keys = {
      { "<leader>co", "<cmd>Outline<CR>", desc = "Toggle Outline" },
    },
    config = true,
  },

  -- Peek definitions, references
  {
    "dnlhc/glance.nvim",
    config = function()
      require("glance").setup()
      vim.keymap.set("n", "gd", "<cmd>Glance definitions<CR>", { desc = "Peek Definition" })
      vim.keymap.set("n", "gr", "<cmd>Glance references<CR>", { desc = "Peek References" })
    end,
  },

  -- Diagnostic lists
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
    keys = {
      { "<leader>xx", "<cmd>TroubleToggle<cr>", desc = "Toggle Trouble" },
      { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics" },
      { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Document Diagnostics" },
      { "<leader>xl", "<cmd>TroubleToggle loclist<cr>", desc = "Location List" },
      { "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", desc = "Quickfix List" },
    },
    opts = {},
  },

  -- LSP installer and bridge
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = true,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "ts_ls",
          "html",
          "cssls",
          "jsonls",
          "eslint",
          "tailwindcss",
          "gopls",
        },
      })
    end,
  },

  -- LSP setup
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = vim.lsp.protocol.make_client_capabilities()

      -- If cmp_nvim_lsp is installed, enhance capabilities
      local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok_cmp then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end

      local function on_attach(client, bufnr)
        vim.diagnostic.config({
          virtual_text = true,
          signs = true,
          underline = true,
          update_in_insert = false,
          severity_sort = true,
        })

        vim.api.nvim_create_autocmd("CursorHold", {
          buffer = bufnr,
          callback = function()
            vim.diagnostic.open_float(nil, { focusable = false })
          end,
        })
      end

      local servers = {
        "lua_ls",
        "ts_ls",
        "html",
        "cssls",
        "jsonls",
        "eslint",
        "tailwindcss",
        "gopls",
      }

      for _, server in ipairs(servers) do
        lspconfig[server].setup({
          capabilities = capabilities,
          on_attach = on_attach,
        })
      end
    end,
  },

  -- LSP progress indicator
  {
    "j-hui/fidget.nvim",
    tag = "legacy",
    event = "LspAttach",
    config = true,
  },

  -- Autoformat on save
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        lua = { "stylua" },
        go = { "gofmt" },
      },
    },
  },
}
