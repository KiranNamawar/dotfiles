-- ============================================================================
-- EDITOR ENHANCEMENTS
-- ============================================================================
-- Enhanced editing experience with modern tools and optimizations

return {
  -- Enhanced completion with blink.cmp (LazyVim Extra)
  {
    "saghen/blink.cmp",
    version = "1.*", -- Use stable releases with prebuilt binaries
    build = "cargo build --release", -- Fallback: build from source if prebuilt binaries fail
    opts = {
      keymap = {
        preset = "default",
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
        ["<C-y>"] = { "select_and_accept" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<Tab>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
      -- Fuzzy matching configuration
      fuzzy = {
        implementation = "lua", -- Use Lua implementation to avoid binary download warnings
        prebuilt_binaries = {
          download = false, -- Disable prebuilt binary downloads
          force_version = nil,
        },
      },
      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant = "mono",
        kind_icons = {
          Text = "󰉿",
          Method = "󰆧",
          Function = "󰊕",
          Constructor = "󰏗",
          Field = "󰜢",
          Variable = "󰀫",
          Class = "󰠱",
          Interface = "󰜰",
          Module = "󰏗",
          Property = "󰜢",
          Unit = "󰑭",
          Value = "󰎠",
          Enum = "󰕘",
          Keyword = "󰌋",
          Snippet = "󰆐",
          Color = "󰏘",
          File = "󰈙",
          Reference = "󰈇",
          Folder = "󰉋",
          EnumMember = "󰕘",
          Constant = "󰏿",
          Struct = "󰙅",
          Event = "󰉁",
          Operator = "󰆕",
          TypeParameter = "󰊄",
        },
      },
      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        menu = {
          draw = {
            treesitter = { "lsp" },
            columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          },
          border = "rounded",
          winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          treesitter_highlighting = true,
          window = {
            border = "rounded",
            winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,CursorLine:BlinkCmpDocCursorLine,Search:None",
          },
        },
        ghost_text = {
          enabled = vim.g.ai_cmp,
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = {
            name = "LSP",
            module = "blink.cmp.sources.lsp",
            opts = {
              -- Show function signatures
              show_signature_help = true,
            },
          },
          path = {
            name = "Path",
            module = "blink.cmp.sources.path",
            opts = {
              trailing_slash = false,
              label_trailing_slash = true,
              get_cwd = function(context)
                return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
              end,
              show_hidden_files_by_default = false,
            },
          },
          snippets = {
            name = "Snippets",
            module = "blink.cmp.sources.snippets",
            opts = {
              friendly_snippets = true,
              search_paths = { vim.fn.stdpath("config") .. "/snippets" },
              global_snippets = { "all" },
              extended_filetypes = {},
              ignored_filetypes = {},
            },
          },
          buffer = {
            name = "Buffer",
            module = "blink.cmp.sources.buffer",
            opts = {
              min_keyword_length = 3,
              max_items = 5,
            },
          },
        },
      },
    },
  },

  -- Better text objects with treesitter
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    enabled = true,
    config = function()
      -- If treesitter is already loaded, we need to run config again for textobjects
      if LazyVim.is_loaded("nvim-treesitter") then
        local opts = LazyVim.opts("nvim-treesitter")
        require("nvim-treesitter.configs").setup({ textobjects = opts.textobjects })
      end

      -- When in diff mode, we want to use the default
      -- vim text objects c & C instead of the treesitter ones.
      local move = require("nvim-treesitter.textobjects.move") ---@type table<string,fun(...)>
      local configs = require("nvim-treesitter.configs")
      for name, fn in pairs(move) do
        if name:find("goto") == 1 then
          move[name] = function(q, ...)
            if vim.wo.diff then
              local config = configs.get_module("textobjects.move")[name] ---@type table<string,string>
              for key, query in pairs(config or {}) do
                if q == query and key:find("[%]%[][cC]") then
                  vim.cmd("normal! " .. key)
                  return
                end
              end
            end
            return fn(q, ...)
          end
        end
      end
    end,
  },

  -- Enhanced treesitter configuration
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Extend the default ensure_installed list
      vim.list_extend(opts.ensure_installed, {
        "bash",
        "c",
        "cpp",
        "css",
        "dockerfile",
        "go",
        "html",
        "http",
        "javascript",
        "jsdoc",
        "json",
        "jsonc",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "rust",
        "scss",
        "sql",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
        "zig",
      })
      
      -- Enhanced treesitter configuration
      opts.highlight = { 
        enable = true,
        additional_vim_regex_highlighting = false,
      }
      opts.indent = { enable = true, disable = { "python" } }
      opts.incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      }
      opts.textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
            ["ab"] = "@block.outer",
            ["ib"] = "@block.inner",
            ["al"] = "@loop.outer",
            ["il"] = "@loop.inner",
            ["ai"] = "@conditional.outer",
            ["ii"] = "@conditional.inner",
            ["ak"] = "@comment.outer",
            ["ik"] = "@comment.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            ["]f"] = "@function.outer",
            ["]c"] = "@class.outer",
            ["]a"] = "@parameter.inner",
            ["]b"] = "@block.outer",
            ["]l"] = "@loop.outer",
            ["]i"] = "@conditional.outer",
            ["]k"] = "@comment.outer",
          },
          goto_next_end = {
            ["]F"] = "@function.outer",
            ["]C"] = "@class.outer",
            ["]A"] = "@parameter.inner",
            ["]B"] = "@block.outer",
            ["]L"] = "@loop.outer",
            ["]I"] = "@conditional.outer",
            ["]K"] = "@comment.outer",
          },
          goto_previous_start = {
            ["[f"] = "@function.outer",
            ["[c"] = "@class.outer",
            ["[a"] = "@parameter.inner",
            ["[b"] = "@block.outer",
            ["[l"] = "@loop.outer",
            ["[i"] = "@conditional.outer",
            ["[k"] = "@comment.outer",
          },
          goto_previous_end = {
            ["[F"] = "@function.outer",
            ["[C"] = "@class.outer",
            ["[A"] = "@parameter.inner",
            ["[B"] = "@block.outer",
            ["[L"] = "@loop.outer",
            ["[I"] = "@conditional.outer",
            ["[K"] = "@comment.outer",
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ["<leader>sn"] = "@parameter.inner",
            ["<leader>sf"] = "@function.outer",
          },
          swap_previous = {
            ["<leader>sp"] = "@parameter.inner",
            ["<leader>sF"] = "@function.outer",
          },
        },
      }
      
      return opts
    end,
  },

  -- Enhanced which-key configuration
  {
    "folke/which-key.nvim",
    opts = {
      preset = "modern",
      delay = 300,
      expand = 1,
      notify = false,
      triggers = {
        { "<auto>", mode = "nxsot" },
        { "s", mode = { "n", "v" } },
      },
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "file/find" },
        { "<leader>g", group = "git" },
        { "<leader>h", group = "hunks" },
        { "<leader>l", group = "location list" },
        { "<leader>m", group = "markdown" },
        { "<leader>n", group = "noice" },
        { "<leader>o", group = "open" },
        { "<leader>p", group = "projects" },
        { "<leader>q", group = "quit/session" },
        { "<leader>r", group = "rename/replace" },
        { "<leader>s", group = "search/swap" },
        { "<leader>t", group = "toggle/test" },
        { "<leader>u", group = "ui" },
        { "<leader>w", group = "windows" },
        { "<leader>x", group = "diagnostics/quickfix" },
        { "<leader>y", group = "yank" },
        { "<leader>z", group = "fold" },
        { "<leader><tab>", group = "tabs" },
        { "]", group = "next" },
        { "[", group = "prev" },
        { "g", group = "goto" },
        { "gs", group = "surround" },
        { "z", group = "fold" },
        
        -- WSL specific
        { "<leader>wy", desc = "Copy to Windows clipboard", hidden = not vim.fn.has("wsl") },
        
        -- Hide some mappings
        { "<leader>w<", hidden = true },
        { "<leader>w>", hidden = true },
        { "<leader>w+", hidden = true },
        { "<leader>w-", hidden = true },
        { "<leader>w_", hidden = true },
        { "<leader>w|", hidden = true },
        { "<leader>wh", hidden = true },
        { "<leader>wj", hidden = true },
        { "<leader>wk", hidden = true },
        { "<leader>wl", hidden = true },
      },
      win = {
        border = "rounded",
        padding = { 1, 2 },
        wo = {
          winblend = 0, -- Remove transparency to prevent dashboard bleed-through
        },
      },
      layout = {
        width = { min = 20, max = 50 },
        height = { min = 4, max = 25 },
        spacing = 3,
        align = "left",
      },
      keys = {
        scroll_down = "<c-d>",
        scroll_up = "<c-u>",
      },
      sort = { "local", "order", "group", "alphanum", "mod" },
      expand = 0,
      replace = {
        key = {
          function(key)
            return require("which-key.view").format(key)
          end,
        },
        desc = {
          { "<Plug>%(?(.*)%)?", "%1" },
          { "^%+", "" },
          { "<[cC]md>", "" },
          { "<[cC][rR]>", "" },
          { "<[sS]ilent>", "" },
          { "^lua%s+", "" },
          { "^call%s+", "" },
          { "^:%s*", "" },
        },
      },
    },
  },

  -- Better search and replace
  {
    "nvim-pack/nvim-spectre",
    build = false,
    cmd = "Spectre",
    opts = { open_cmd = "noswapfile vnew" },
    keys = {
      { "<leader>sr", function() require("spectre").open() end, desc = "Replace in files (Spectre)" },
      { "<leader>sR", function() require("spectre").open_visual({ select_word = true }) end, desc = "Replace current word (Spectre)" },
      { "<leader>sf", function() require("spectre").open_file_search({ select_word = true }) end, desc = "Replace in current file (Spectre)" },
    },
  },

  -- Enhanced telescope configuration
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- Add custom telescope keymaps
      {
        "<leader>fp",
        function()
          require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root })
        end,
        desc = "Find Plugin File",
      },
      {
        "<leader>fP",
        function()
          require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("data") .. "/lazy" })
        end,
        desc = "Find Plugin Data",
      },
      {
        "<leader>fc",
        function()
          require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "Find Config File",
      },
      {
        "<leader>fh",
        function()
          require("telescope.builtin").find_files({ cwd = vim.fn.expand("~") })
        end,
        desc = "Find Files in Home",
      },
      {
        "<leader>fC",
        function()
          require("telescope.builtin").commands()
        end,
        desc = "Find Commands",
      },
      {
        "<leader>fH",
        function()
          require("telescope.builtin").help_tags()
        end,
        desc = "Find Help",
      },
      {
        "<leader>fk",
        function()
          require("telescope.builtin").keymaps()
        end,
        desc = "Find Keymaps",
      },
      {
        "<leader>fo",
        function()
          require("telescope.builtin").vim_options()
        end,
        desc = "Find Options",
      },
      {
        "<leader>fR",
        function()
          require("telescope.builtin").resume()
        end,
        desc = "Resume Search",
      },
      {
        "<leader>fw",
        function()
          require("telescope.builtin").grep_string({ word_match = "-w" })
        end,
        desc = "Find Word",
      },
      {
        "<leader>fW",
        function()
          require("telescope.builtin").grep_string()
        end,
        desc = "Find Word (no boundary)",
      },
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers({ sort_mru = true, sort_lastused = true })
        end,
        desc = "Find Buffers",
      },
    },
    opts = function(_, opts)
      local actions = require("telescope.actions")
      local trouble = require("trouble.sources.telescope")
      
      opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
        prompt_prefix = "   ",
        selection_caret = "  ",
        entry_prefix = "  ",
        initial_mode = "insert",
        selection_strategy = "reset",
        sorting_strategy = "ascending",
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = {
            prompt_position = "top",
            preview_width = 0.55,
            results_width = 0.8,
          },
          vertical = {
            mirror = false,
          },
          width = 0.87,
          height = 0.80,
          preview_cutoff = 120,
        },
        winblend = 0, -- Remove transparency to prevent dashboard bleed-through
        border = true,
        borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
        color_devicons = true,
        use_less = true,
        path_display = { "truncate" },
        set_env = { ["COLORTERM"] = "truecolor" },
        file_ignore_patterns = {
          "%.git/",
          "node_modules/",
          "%.npm/",
          "__pycache__/",
          "%.pyc",
          "%.pyo",
          "%.exe",
          "%.dll",
          "%.so",
          "%.dylib",
          "%.class",
          "%.jar",
          "%.zip",
          "%.tar.gz",
          "%.tar.bz2",
          "%.rar",
          "%.7z",
          "%.png",
          "%.jpg",
          "%.jpeg",
          "%.gif",
          "%.bmp",
          "%.ico",
          "%.svg",
          "%.tiff",
          "%.psd",
          "%.ai",
          "%.pdf",
          "%.doc",
          "%.docx",
          "%.xls",
          "%.xlsx",
          "%.ppt",
          "%.pptx",
          "%.mp3",
          "%.mp4",
          "%.mkv",
          "%.mov",
          "%.wmv",
          "%.flv",
          "%.avi",
          "%.webm",
          "%.m4a",
          "%.ogg",
          "%.flac",
          "%.wav",
        },
        mappings = {
          i = {
            ["<C-t>"] = trouble.open,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-n>"] = actions.cycle_history_next,
            ["<C-p>"] = actions.cycle_history_prev,
            ["<C-u>"] = actions.preview_scrolling_up,
            ["<C-d>"] = actions.preview_scrolling_down,
            ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
            ["<C-l>"] = actions.complete_tag,
            ["<C-/>"] = actions.which_key,
            ["<C-_>"] = actions.which_key, -- for which-key
            ["<C-w>"] = { "<c-s-w>", type = "command" },
            ["<C-r><C-w>"] = actions.insert_original_cword,
          },
          n = {
            ["<C-t>"] = trouble.open,
            ["q"] = actions.close,
            ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
            ["<C-/>"] = actions.which_key,
            ["<C-_>"] = actions.which_key, -- for which-key
          },
        },
      })
      
      opts.pickers = {
        find_files = {
          find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
          hidden = true,
          follow = true,
        },
        live_grep = {
          additional_args = function()
            return { "--hidden", "--glob", "!**/.git/*" }
          end,
        },
        grep_string = {
          additional_args = function()
            return { "--hidden", "--glob", "!**/.git/*" }
          end,
        },
        buffers = {
          theme = "ivy",
          previewer = false,
          initial_mode = "normal",
          mappings = {
            i = {
              ["<C-d>"] = actions.delete_buffer,
            },
            n = {
              ["dd"] = actions.delete_buffer,
            },
          },
        },
        oldfiles = {
          theme = "ivy",
          previewer = false,
          initial_mode = "normal",
        },
        current_buffer_fuzzy_find = {
          theme = "ivy",
          previewer = false,
          initial_mode = "normal",
        },
        help_tags = {
          theme = "ivy",
          previewer = false,
          initial_mode = "normal",
        },
        keymaps = {
          theme = "ivy",
          previewer = false,
          initial_mode = "normal",
        },
        commands = {
          theme = "ivy",
          previewer = false,
          initial_mode = "normal",
        },
      }
      
      return opts
    end,
  },

  -- Better quickfix
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
      auto_enable = true,
      preview = {
        win_height = 12,
        win_vheight = 12,
        delay_syntax = 80,
        border = "rounded",
        show_title = true,
        should_preview_cb = function(bufnr, qwinid)
          local ret = true
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          local fsize = vim.fn.getfsize(bufname)
          if fsize > 100 * 1024 then
            -- Skip preview for files larger than 100KB
            ret = false
          elseif bufname:match("^fugitive://") then
            -- Skip preview for fugitive buffers
            ret = false
          end
          return ret
        end,
      },
      func_map = {
        vsplit = "",
        ptogglemode = "z,",
        stoggleup = "",
      },
      filter = {
        fzf = {
          action_for = { ["ctrl-s"] = "split" },
          extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
        },
      },
    },
  },
}
