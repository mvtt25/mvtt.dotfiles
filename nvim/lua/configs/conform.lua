local prettier = { "prettier" }

return {
  formatters_by_ft = {
    lua = { "stylua" },
    javascript = prettier,
    javascriptreact = prettier,
    typescript = prettier,
    typescriptreact = prettier,
    json = prettier,
    jsonc = prettier,
    css = prettier,
    html = prettier,
    sh = { "shfmt" },
    bash = { "shfmt" },
    nix = { "nixfmt" },
  },
  -- Prettier only where the project configures it; elsewhere the language server formats.
  formatters = { prettier = { require_cwd = true } },
  -- Format on save, as LazyVim did. Go, Rust, Terraform, TOML and YAML go through their servers.
  format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
}
