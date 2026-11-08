require "nvchad.mappings"

-- LazyVim's everyday keys, on NvChad's tools (telescope, gitsigns, tabufline, nvchad.term).
-- Plugin keys (debug <leader>d…, tests <leader>t…) sit in plugins/init.lua and match LazyVim's too.
-- Left out: <M-j>/<M-k> (OmniWM owns alt-j/k) and the keys of plugins NvChad lacks
-- (flash, trouble, yanky, sessions).
local map = vim.keymap.set

local function pick(name)
  return function()
    require("telescope.builtin")[name]()
  end
end

-- find and search
map("n", "<leader><space>", pick "find_files", { desc = "Find Files" })
map("n", "<leader>/", pick "live_grep", { desc = "Grep" })
map("n", "<leader>,", pick "buffers", { desc = "Buffers" })
map("n", "<leader>:", pick "command_history", { desc = "Command History" })
map("n", "<leader>fr", pick "oldfiles", { desc = "Recent" })
map("n", "<leader>sg", pick "live_grep", { desc = "Grep" })
map("n", "<leader>sw", pick "grep_string", { desc = "Word under cursor" })
map("n", "<leader>sk", pick "keymaps", { desc = "Keymaps" })
map("n", "<leader>sh", pick "help_tags", { desc = "Help Pages" })
map("n", "<leader>sd", pick "diagnostics", { desc = "Diagnostics" })
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Explorer" })

-- buffers and windows
map("n", "H", function() require("nvchad.tabufline").prev() end, { desc = "Prev Buffer" })
map("n", "L", function() require("nvchad.tabufline").next() end, { desc = "Next Buffer" })
map("n", "<leader>bd", function() require("nvchad.tabufline").close_buffer() end, { desc = "Delete Buffer" })
map("n", "<leader>bo", function() require("nvchad.tabufline").closeAllBufs(false) end, { desc = "Delete Other Buffers" })
map("n", "<leader>-", "<C-W>s", { desc = "Split Window Below", remap = true })
map("n", "<leader>|", "<C-W>v", { desc = "Split Window Right", remap = true })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete Window", remap = true })
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- code
map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
map("n", "<leader>cr", require "nvchad.lsp.renamer", { desc = "Rename" })
map({ "n", "x" }, "<leader>cf", function() require("conform").format { lsp_format = "fallback" } end, { desc = "Format" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map("n", "<leader>cm", "<cmd>Mason<cr>", { desc = "Mason" })
map("n", "gr", pick "lsp_references", { desc = "References" })
map("n", "gI", pick "lsp_implementations", { desc = "Goto Implementation" })
map("n", "gy", pick "lsp_type_definitions", { desc = "Goto T[y]pe Definition" })
for key, severity in pairs { e = "ERROR", w = "WARN" } do
  local s = vim.diagnostic.severity[severity]
  map("n", "]" .. key, function() vim.diagnostic.jump { count = 1, severity = s } end, { desc = "Next " .. severity })
  map("n", "[" .. key, function() vim.diagnostic.jump { count = -1, severity = s } end, { desc = "Prev " .. severity })
end
map("x", "<", "<gv", { desc = "Indent left, keep selection" })
map("x", ">", ">gv", { desc = "Indent right, keep selection" })

-- git
map("n", "]h", function() require("gitsigns").nav_hunk "next" end, { desc = "Next Hunk" })
map("n", "[h", function() require("gitsigns").nav_hunk "prev" end, { desc = "Prev Hunk" })
map("n", "<leader>ghs", function() require("gitsigns").stage_hunk() end, { desc = "Stage Hunk" })
map("n", "<leader>ghr", function() require("gitsigns").reset_hunk() end, { desc = "Reset Hunk" })
map("n", "<leader>ghp", function() require("gitsigns").preview_hunk_inline() end, { desc = "Preview Hunk Inline" })
map("n", "<leader>gb", function() require("gitsigns").blame_line { full = true } end, { desc = "Git Blame Line" })
map("n", "<leader>gs", pick "git_status", { desc = "Git Status" })
map("n", "<leader>gc", pick "git_commits", { desc = "Git Log" })
map("n", "<leader>gg", function()
  require("nvchad.term").toggle { pos = "float", id = "lazygit", cmd = "lazygit" }
end, { desc = "Lazygit" })

-- terminal (<C-_> is what terminals send for <C-/>)
for _, key in ipairs { "<C-/>", "<C-_>" } do
  map({ "n", "t" }, key, function() require("nvchad.term").toggle { pos = "float", id = "floatTerm" } end, { desc = "Terminal" })
end

-- toggles
map("n", "<leader>ul", "<cmd>set number!<cr>", { desc = "Toggle Line Numbers" })
map("n", "<leader>uL", "<cmd>set relativenumber!<cr>", { desc = "Toggle Relative Number" })
map("n", "<leader>uw", "<cmd>set wrap!<cr>", { desc = "Toggle Wrap" })
