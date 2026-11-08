require "nvchad.autocmds"

-- `nvim <dir>` opens the project in the file tree, as LazyVim's explorer did:
-- NvChad disables netrw and loads nvim-tree only on demand.
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local dir = vim.fn.argv(0)
    if vim.fn.argc() ~= 1 or vim.fn.isdirectory(dir) == 0 then
      return
    end
    vim.cmd.cd(dir)
    require("nvim-tree.api").tree.open()
    -- nvim-tree wipes the directory buffer without a BufDelete, which is what tells
    -- NvChad's buffer line to forget it: drop the dead entry, or the next file errors.
    vim.schedule(function()
      vim.t.bufs = vim.tbl_filter(vim.api.nvim_buf_is_valid, vim.t.bufs or {})
    end)
  end,
})
