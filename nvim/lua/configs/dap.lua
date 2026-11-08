local dap, dapui = require "dap", require "dapui"

-- The UI follows the debug session.
dap.listeners.after.event_initialized.dapui = dapui.open
dap.listeners.before.event_terminated.dapui = dapui.close
dap.listeners.before.event_exited.dapui = dapui.close

-- TypeScript/JavaScript on Node: vscode-js-debug from Mason. Projects with a
-- .vscode/launch.json get its configurations too.
dap.adapters["pwa-node"] = {
  type = "server",
  host = "localhost",
  port = "${port}",
  executable = { command = "js-debug-adapter", args = { "${port}" } },
}
-- VS Code's launch.json says "type": "node": hand it to the same adapter.
dap.adapters.node = vim.tbl_extend("force", dap.adapters["pwa-node"], {
  enrich_config = function(config, on_config)
    on_config(vim.tbl_extend("force", config, { type = "pwa-node" }))
  end,
})
for _, ft in ipairs { "javascript", "javascriptreact", "typescript", "typescriptreact" } do
  dap.configurations[ft] = {
    { type = "pwa-node", request = "launch", name = "Launch current file", program = "${file}", cwd = "${workspaceFolder}" },
    {
      type = "pwa-node",
      request = "attach",
      name = "Attach to a Node process",
      processId = require("dap.utils").pick_process,
      cwd = "${workspaceFolder}",
    },
  }
end

-- Rust: codelldb from Mason, on a binary cargo has built. Go is set up by nvim-dap-go.
dap.adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = { command = "codelldb", args = { "--port", "${port}" } },
}
dap.configurations.rust = {
  {
    type = "codelldb",
    request = "launch",
    name = "Launch a cargo binary",
    program = function()
      return vim.fn.input("Binary: ", vim.fn.getcwd() .. "/target/debug/", "file")
    end,
    cwd = "${workspaceFolder}",
  },
}
