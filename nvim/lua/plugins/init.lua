-- On top of NvChad's own plugins (nvchad.plugins): languages, debugging and tests.

return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = { "b0o/SchemaStore.nvim" },
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- NvChad's own
        "lua",
        "luadoc",
        "printf",
        "vim",
        "vimdoc",
        -- web
        "javascript",
        "typescript",
        "tsx",
        "jsdoc",
        "json",
        "html",
        "css",
        "prisma",
        -- infra
        "terraform",
        "hcl",
        "yaml",
        "helm",
        "toml",
        "dockerfile",
        "bash",
        "nix",
        -- go and rust
        "go",
        "gomod",
        "gosum",
        "gowork",
        "rust",
        -- everyday
        "markdown",
        "markdown_inline",
        "regex",
        "diff",
        "gitcommit",
        "git_config",
        "gitignore",
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
      { "leoluz/nvim-dap-go", opts = {} },
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug toggle breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Debug start or continue" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Debug step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Debug step into" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Debug step out" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Debug terminate" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Debug toggle UI" },
    },
    config = function()
      require "configs.dap"
    end,
  },

  -- The keys and jest settings are the ones the LazyVim setup had.
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-jest",
      "marilari88/neotest-vitest",
      "fredrikaverpil/neotest-golang",
    },
    keys = {
      { "<leader>tt", function() require("neotest").run.run() end, desc = "Test run nearest" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand "%") end, desc = "Test run file" },
      { "<leader>ta", function() require("neotest").run.run(vim.fn.getcwd()) end, desc = "Test run all" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test toggle summary" },
      {
        "<leader>to",
        function() require("neotest").output.open { enter = true, auto_close = true } end,
        desc = "Test show output",
      },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Test toggle output panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Test stop" },
      { "<leader>tw", function() require("neotest").watch.toggle() end, desc = "Test toggle watch" },
    },
    config = function()
      require("neotest").setup {
        adapters = {
          require "neotest-jest" {
            jestCommand = "npm test --",
            jestConfigFile = "jest.config.js",
            env = { CI = true },
            cwd = function()
              return vim.fn.getcwd()
            end,
          },
          require "neotest-vitest",
          require "neotest-golang" {},
        },
        status = { virtual_text = true, signs = true },
        output = { open_on_run = true },
        quickfix = { open = false },
      }
    end,
  },
}
