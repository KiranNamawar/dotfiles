-- ============================================================================
-- AI AND CODING ENHANCEMENTS
-- ============================================================================
-- Advanced AI assistance, code generation, and intelligent coding features

return {
  -- GitHub Copilot (LazyVim Extra)
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 75,
        keymap = {
          accept = "<M-l>",
          accept_word = false,
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
        layout = {
          position = "bottom",
          ratio = 0.4,
        },
      },
      filetypes = {
        yaml = false,
        markdown = false,
        help = false,
        gitcommit = false,
        gitrebase = false,
        hgcommit = false,
        svn = false,
        cvs = false,
        ["."] = false,
      },
      copilot_node_command = "node",
      server_opts_overrides = {},
    },
  },

  -- Copilot Chat (LazyVim Extra)
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    opts = {
      debug = false,
      question_header = "## User ",
      answer_header = "## Copilot ",
      error_header = "## Error ",
      separator = " ",
      prompts = {
        Explain = {
          prompt = "/COPILOT_EXPLAIN Write an explanation for the active selection as paragraphs of text.",
        },
        Review = {
          prompt = "/COPILOT_REVIEW Review the selected code.",
          callback = function(response, source)
            local ns = vim.api.nvim_create_namespace("copilot_review")
            local diagnostics = {}
            for line in response:gmatch("[^\r\n]+") do
              if line:find("^Issue") then
                local lnum = line:match(":(%d+):")
                if lnum then
                  table.insert(diagnostics, {
                    lnum = tonumber(lnum) - 1,
                    col = 0,
                    message = line,
                    severity = vim.diagnostic.severity.WARN,
                    source = "Copilot Review",
                  })
                end
              end
            end
            vim.diagnostic.set(ns, source.bufnr, diagnostics)
          end,
        },
        Fix = {
          prompt = "/COPILOT_GENERATE There is a problem in this code. Rewrite the code to fix the problem.",
        },
        Optimize = {
          prompt = "/COPILOT_GENERATE Optimize the selected code to improve performance and readability.",
        },
        Docs = {
          prompt = "/COPILOT_GENERATE Please add documentation comment for the selection.",
        },
        Tests = {
          prompt = "/COPILOT_GENERATE Please generate tests for my code.",
        },
        FixDiagnostic = {
          prompt = "Please assist with the following diagnostic issue in file:",
          selection = function(source)
            local diagnostics = vim.diagnostic.get(source.bufnr)
            local line_diagnostics = {}
            for _, diagnostic in ipairs(diagnostics) do
              if diagnostic.lnum == vim.fn.line(".") - 1 then
                table.insert(line_diagnostics, diagnostic.message)
              end
            end
            return table.concat(line_diagnostics, "\n")
          end,
        },
        Commit = {
          prompt = "Write commit message for the change with commitizen convention. Make sure the title has maximum 50 characters and message is wrapped at 72 characters. Wrap the whole message in code block with language gitcommit.",
          selection = function(source)
            return require("CopilotChat.integrations.cmp").diff()
          end,
        },
        CommitStaged = {
          prompt = "Write commit message for the change with commitizen convention. Make sure the title has maximum 50 characters and message is wrapped at 72 characters. Wrap the whole message in code block with language gitcommit.",
          selection = function(source)
            return require("CopilotChat.integrations.cmp").diff("staged")
          end,
        },
      },
      auto_follow_cursor = true,
      show_help = true,
      mappings = {
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-r>",
          insert = "<C-r>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-s>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        yank_diff = {
          normal = "gy",
        },
        show_diff = {
          normal = "gd",
        },
        show_system_prompt = {
          normal = "gp",
        },
        show_user_selection = {
          normal = "gs",
        },
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      local select = require("CopilotChat.select")
      
      -- Use unnamed register for the selection
      opts.selection = select.unnamed
      
      chat.setup(opts)
      
      vim.api.nvim_create_user_command("CopilotChatVisual", function(args)
        chat.ask(args.args, { selection = select.visual })
      end, { nargs = "*", range = true })
      
      -- Inline chat with Copilot
      vim.api.nvim_create_user_command("CopilotChatInline", function(args)
        chat.ask(args.args, {
          selection = select.visual,
          window = {
            layout = "float",
            relative = "cursor",
            width = 1,
            height = 0.4,
            row = 1,
          },
        })
      end, { nargs = "*", range = true })
      
      -- Disable completion for Copilot chat buffers
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-*",
        callback = function()
          -- Disable blink.cmp for copilot chat buffers
          vim.b.blink_cmp_enabled = false
        end,
      })
      
      vim.api.nvim_create_autocmd("BufLeave", {
        pattern = "copilot-*",
        callback = function()
          -- Re-enable blink.cmp when leaving copilot chat buffers
          vim.b.blink_cmp_enabled = true
        end,
      })
    end,
    event = "VeryLazy",
    keys = {
      {
        "<leader>ccq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
          end
        end,
        desc = "CopilotChat - Quick question",
      },
      {
        "<leader>cch",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.help_actions())
        end,
        desc = "CopilotChat - Help actions",
      },
      {
        "<leader>ccp",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
        end,
        desc = "CopilotChat - Prompt actions",
      },
      {
        "<leader>ccp",
        ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions({selection = require('CopilotChat.select').visual}))<CR>",
        mode = "x",
        desc = "CopilotChat - Prompt actions",
      },
      {
        "<leader>cce",
        "<cmd>CopilotChatExplain<cr>",
        desc = "CopilotChat - Explain code",
      },
      {
        "<leader>cct",
        "<cmd>CopilotChatTests<cr>",
        desc = "CopilotChat - Generate tests",
      },
      {
        "<leader>ccr",
        "<cmd>CopilotChatReview<cr>",
        desc = "CopilotChat - Review code",
      },
      {
        "<leader>ccR",
        "<cmd>CopilotChatRefactor<cr>",
        desc = "CopilotChat - Refactor code",
      },
      {
        "<leader>ccn",
        "<cmd>CopilotChatBetterNamings<cr>",
        desc = "CopilotChat - Better Naming",
      },
      {
        "<leader>ccv",
        ":CopilotChatVisual",
        mode = "x",
        desc = "CopilotChat - Open in vertical split",
      },
      {
        "<leader>ccx",
        ":CopilotChatInline<cr>",
        mode = "x",
        desc = "CopilotChat - Inline chat",
      },
      {
        "<leader>cci",
        function()
          local input = vim.fn.input("Ask Copilot: ")
          if input ~= "" then
            vim.cmd("CopilotChat " .. input)
          end
        end,
        desc = "CopilotChat - Ask input",
      },
      {
        "<leader>ccm",
        "<cmd>CopilotChatCommit<cr>",
        desc = "CopilotChat - Generate commit message",
      },
      {
        "<leader>ccM",
        "<cmd>CopilotChatCommitStaged<cr>",
        desc = "CopilotChat - Generate commit message for staged changes",
      },
      {
        "<leader>ccd",
        "<cmd>CopilotChatFixDiagnostic<cr>",
        desc = "CopilotChat - Fix Diagnostic",
      },
      {
        "<leader>ccl",
        function()
          local line = vim.fn.line(".")
          local col = vim.fn.col(".")
          local text = vim.fn.getline(line)
          require("CopilotChat").ask("Explain this line: " .. text, {
            selection = function()
              return text
            end,
          })
        end,
        desc = "CopilotChat - Explain line",
      },
    },
  },

  -- Supermaven (LazyVim Extra) - Another AI completion provider
  {
    "supermaven-inc/supermaven-nvim",
    opts = {
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
      ignore_filetypes = { cpp = true },
      color = {
        suggestion_color = "#ffffff",
        cterm = 244,
      },
      log_level = "info", -- set to "off" to disable logging completely
      disable_inline_completion = false, -- disables inline completion for use with blink.cmp
      disable_keymaps = false, -- disables built in keymaps for more manual control
    },
  },

  -- Enhanced code actions with refactoring
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      {
        "<leader>re",
        function() require("refactoring").refactor("Extract Function") end,
        mode = "x",
        desc = "Extract Function",
      },
      {
        "<leader>rf",
        function() require("refactoring").refactor("Extract Function To File") end,
        mode = "x",
        desc = "Extract Function To File",
      },
      {
        "<leader>rv",
        function() require("refactoring").refactor("Extract Variable") end,
        mode = "x",
        desc = "Extract Variable",
      },
      {
        "<leader>ri",
        function() require("refactoring").refactor("Inline Variable") end,
        mode = { "n", "x" },
        desc = "Inline Variable",
      },
      {
        "<leader>rb",
        function() require("refactoring").refactor("Extract Block") end,
        desc = "Extract Block",
      },
      {
        "<leader>rbf",
        function() require("refactoring").refactor("Extract Block To File") end,
        desc = "Extract Block To File",
      },
      {
        "<leader>rr",
        function() require("refactoring").select_refactor() end,
        mode = { "n", "x" },
        desc = "Select Refactor",
      },
      {
        "<leader>rp",
        function() require("refactoring").debug.printf({ below = false }) end,
        desc = "Debug Print",
      },
      {
        "<leader>rc",
        function() require("refactoring").debug.cleanup({}) end,
        desc = "Debug Cleanup",
      },
    },
    opts = {
      prompt_func_return_type = {
        go = false,
        java = false,
        cpp = false,
        c = false,
        h = false,
        hpp = false,
        cxx = false,
      },
      prompt_func_param_type = {
        go = false,
        java = false,
        cpp = false,
        c = false,
        h = false,
        hpp = false,
        cxx = false,
      },
      printf_statements = {},
      print_var_statements = {},
      show_success_message = false,
    },
    config = function(_, opts)
      require("refactoring").setup(opts)
      
      -- Load refactoring Telescope extension if available
      if LazyVim.has("telescope.nvim") then
        LazyVim.on_load("telescope.nvim", function()
          require("telescope").load_extension("refactoring")
        end)
      end
    end,
  },

  -- Enhanced code generation and snippets
  {
    "L3MON4D3/LuaSnip",
    build = (function()
      if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
        return
      end
      return "make install_jsregexp"
    end)(),
    dependencies = {
      {
        "rafamadriz/friendly-snippets",
        config = function()
          require("luasnip.loaders.from_vscode").lazy_load()
        end,
      },
    },
    opts = {
      history = true,
      delete_check_events = "TextChanged",
    },
    keys = {
      {
        "<tab>",
        function()
          return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
        end,
        expr = true,
        silent = true,
        mode = "i",
      },
      { "<tab>", function() require("luasnip").jump(1) end, mode = "s" },
      { "<s-tab>", function() require("luasnip").jump(-1) end, mode = { "i", "s" } },
    },
    config = function(_, opts)
      require("luasnip").setup(opts)
      
      -- Load custom snippets
      require("luasnip.loaders.from_lua").load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
      
      -- Create custom snippets directory if it doesn't exist
      local snippets_dir = vim.fn.stdpath("config") .. "/snippets"
      if vim.fn.isdirectory(snippets_dir) == 0 then
        vim.fn.mkdir(snippets_dir, "p")
      end
      
      -- Auto-reload snippets when they change
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*/snippets/*.lua",
        callback = function()
          require("luasnip.loaders.from_lua").load({ paths = { snippets_dir } })
        end,
      })
    end,
  },

  -- Enhanced commenting
  {
    "numToStr/Comment.nvim",
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    keys = {
      { "gcc", mode = "n", desc = "Comment toggle current line" },
      { "gc", mode = { "n", "o" }, desc = "Comment toggle linewise" },
      { "gc", mode = "x", desc = "Comment toggle linewise (visual)" },
      { "gbc", mode = "n", desc = "Comment toggle current block" },
      { "gb", mode = { "n", "o" }, desc = "Comment toggle blockwise" },
      { "gb", mode = "x", desc = "Comment toggle blockwise (visual)" },
    },
    config = function(_, opts)
      require("Comment").setup(vim.tbl_deep_extend("force", opts or {}, {
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      }))
    end,
  },

  -- Enhanced code navigation
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = {
      enable = true,
      max_lines = 0,
      min_window_height = 0,
      line_numbers = true,
      multiline_threshold = 20,
      trim_scope = "outer",
      mode = "cursor",
      separator = nil,
      zindex = 20,
      on_attach = nil,
    },
    keys = {
      {
        "<leader>ut",
        function()
          local tsc = require("treesitter-context")
          tsc.toggle()
          if LazyVim.inject.get_upvalue(tsc.toggle, "enabled") then
            LazyVim.info("Enabled Treesitter Context", { title = "Option" })
          else
            LazyVim.warn("Disabled Treesitter Context", { title = "Option" })
          end
        end,
        desc = "Toggle Treesitter Context",
      },
    },
  },

  -- Code outline and structure
  {
    "stevearc/aerial.nvim",
    opts = {
      backends = { "treesitter", "lsp", "markdown", "man" },
      show_guides = true,
      layout = {
        max_width = { 40, 0.2 },
        width = nil,
        min_width = 10,
        win_opts = {},
        default_direction = "prefer_right",
        placement = "window",
      },
      attach_mode = "window",
      keymaps = {
        ["?"] = "actions.show_help",
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.jump",
        ["<2-LeftMouse>"] = "actions.jump",
        ["<C-v>"] = "actions.jump_vsplit",
        ["<C-s>"] = "actions.jump_split",
        ["p"] = "actions.scroll",
        ["<C-j>"] = "actions.down_and_scroll",
        ["<C-k>"] = "actions.up_and_scroll",
        ["{"] = "actions.prev",
        ["}"] = "actions.next",
        ["[["] = "actions.prev_up",
        ["]]"] = "actions.next_up",
        ["q"] = "actions.close",
        ["o"] = "actions.tree_toggle",
        ["za"] = "actions.tree_toggle",
        ["O"] = "actions.tree_toggle_recursive",
        ["zA"] = "actions.tree_toggle_recursive",
        ["l"] = "actions.tree_open",
        ["zo"] = "actions.tree_open",
        ["L"] = "actions.tree_open_recursive",
        ["zO"] = "actions.tree_open_recursive",
        ["h"] = "actions.tree_close",
        ["zc"] = "actions.tree_close",
        ["H"] = "actions.tree_close_recursive",
        ["zC"] = "actions.tree_close_recursive",
        ["zr"] = "actions.tree_increase_fold_level",
        ["zR"] = "actions.tree_open_all",
        ["zm"] = "actions.tree_decrease_fold_level",
        ["zM"] = "actions.tree_close_all",
        ["zx"] = "actions.tree_sync_folds",
        ["zX"] = "actions.tree_sync_folds",
      },
      lazy_load = true,
      disable_max_lines = 10000,
      disable_max_size = 2000000,
      filter_kind = {
        "Class",
        "Constructor",
        "Enum",
        "Function",
        "Interface",
        "Module",
        "Method",
        "Struct",
      },
      highlight_mode = "split_width",
      highlight_closest = true,
      highlight_on_hover = false,
      highlight_on_jump = 300,
      icons = {},
      ignore = {
        unlisted_buffers = true,
        filetypes = {},
        buftypes = "special",
        wintypes = "special",
      },
      manage_folds = false,
      link_folds_to_tree = false,
      link_tree_to_folds = true,
      nerd_font = "auto",
      on_attach = function(bufnr)
        vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
        vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
      end,
      open_automatic = false,
      post_jump_cmd = "normal! zz",
      close_automatic_events = {},
      post_parse_symbol = nil,
      post_add_all_symbols = nil,
      update_events = "TextChanged,InsertLeave",
      show_trailing_blankline_indent = false,
      treesitter = {
        update_delay = 300,
      },
      markdown = {
        update_delay = 300,
      },
      man = {
        update_delay = 300,
      },
    },
    keys = {
      { "<leader>cs", "<cmd>AerialToggle!<CR>", desc = "Aerial (Symbols)" },
    },
  },

  -- Enhanced code actions UI
  {
    "aznhe21/actions-preview.nvim",
    opts = {
      diff = {
        ctxlen = 3,
      },
      backend = { "telescope" },
      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          width = 0.8,
          height = 0.9,
          prompt_position = "top",
          preview_cutoff = 20,
          preview_height = function(_, _, max_lines)
            return max_lines - 15
          end,
        },
      },
    },
    keys = {
      {
        "<leader>ca",
        function()
          require("actions-preview").code_actions()
        end,
        mode = { "v", "n" },
        desc = "Code Action Preview",
      },
    },
  },

  -- Code documentation generation
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    keys = {
      {
        "<leader>cg",
        function()
          require("neogen").generate({})
        end,
        desc = "Generate Annotations",
      },
      {
        "<leader>cgf",
        function()
          require("neogen").generate({ type = "func" })
        end,
        desc = "Generate Function Annotation",
      },
      {
        "<leader>cgc",
        function()
          require("neogen").generate({ type = "class" })
        end,
        desc = "Generate Class Annotation",
      },
      {
        "<leader>cgt",
        function()
          require("neogen").generate({ type = "type" })
        end,
        desc = "Generate Type Annotation",
      },
      {
        "<leader>cgF",
        function()
          require("neogen").generate({ type = "file" })
        end,
        desc = "Generate File Annotation",
      },
    },
    opts = {
      snippet_engine = "luasnip",
      enabled = true,
      languages = {
        lua = {
          template = {
            annotation_convention = "ldoc",
          },
        },
        python = {
          template = {
            annotation_convention = "google_docstrings",
          },
        },
        rust = {
          template = {
            annotation_convention = "rustdoc",
          },
        },
        javascript = {
          template = {
            annotation_convention = "jsdoc",
          },
        },
        typescript = {
          template = {
            annotation_convention = "tsdoc",
          },
        },
        go = {
          template = {
            annotation_convention = "godoc",
          },
        },
      },
    },
  },
}
