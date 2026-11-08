require("nvchad.configs.lspconfig").defaults()

-- Installed by NvChad's :MasonInstallAll (extras in chadrc.lua); nixd comes from Nix, rust_analyzer from rustup.
local servers = {
  -- web
  "vtsls",
  "eslint",
  "prismals",
  "jsonls",
  "html",
  "cssls",
  -- infra
  "terraformls",
  "ansiblels",
  "dockerls",
  "docker_compose_language_service",
  "yamlls",
  "helm_ls",
  "taplo",
  "bashls",
  "nixd",
  -- go and rust
  "gopls",
  "rust_analyzer",
}

-- JSON and YAML validate against SchemaStore: package.json, tsconfig, GitHub workflows, compose…
vim.lsp.config("jsonls", {
  settings = { json = { schemas = require("schemastore").json.schemas(), validate = { enable = true } } },
})
vim.lsp.config("yamlls", {
  settings = { yaml = { schemaStore = { enable = false, url = "" }, schemas = require("schemastore").yaml.schemas() } },
})
vim.lsp.config("gopls", { settings = { gopls = { gofumpt = true } } })

vim.lsp.enable(servers)
