-- NvChad's own settings. Every option: https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "onedark",
  -- Ghostty's Modest Dark background shows through: editor, terminal and TUIOS are one surface.
  transparency = true,
  -- Modest Dark accents, the palette Zed and Ghostty use.
  changed_themes = {
    onedark = {
      base_30 = {
        black = "#0f1219",
        one_bg = "#1e242e",
        one_bg2 = "#2c313a",
        grey = "#546178",
        red = "#e06c75",
        orange = "#d99a5e",
        yellow = "#ebc275",
        green = "#97ca72",
        cyan = "#56b6c2",
        blue = "#5ab0f6",
        purple = "#ca72e4",
      },
      base_16 = { base00 = "#0f1219" },
    },
  },
  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
  },
}

-- :MasonInstallAll already takes the servers and formatters the configs enable;
-- these are the extras (debug adapters, ansiblels's linter), and rust-analyzer comes from rustup.
M.mason = {
  pkgs = { "js-debug-adapter", "delve", "codelldb", "ansible-lint" },
  skip = { "rust-analyzer" },
}

M.nvdash = {
  load_on_startup = true,
  header = vim.split(
    [[
     ███▄ ▄███▓ ██▒   █▓▄▄▄█████▓▄▄▄█████▓
    ▓██▒▀█▀ ██▒▓██░   █▒▓  ██▒ ▓▒▓  ██▒ ▓▒
    ▓██    ▓██░ ▓██  █▒░▒ ▓██░ ▒░▒ ▓██░ ▒░
    ▒██    ▒██   ▒██ █░░░ ▓██▓ ░ ░ ▓██▓ ░ 
    ▒██▒   ░██▒   ▒▀█░    ▒██▒ ░   ▒██▒ ░ 
    ░ ▒░   ░  ░   ░ ▐░    ▒ ░░     ▒ ░░   
    ░  ░      ░   ░ ░░      ░        ░    
    ░      ░        ░░    ░        ░      
         ░         ░                    
                  ░                     
]],
    "\n"
  ),
}

return M
