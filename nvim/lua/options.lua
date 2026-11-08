require "nvchad.options"

-- Cursor: block in normal/visual/command, blinking bar in insert, underline in replace.
vim.opt.guicursor = {
  "n-v-c:block-Cursor/lCursor",
  "i-ci-ve:ver15-Cursor/lCursor-blinkon500-blinkoff500",
  "r-cr:hor10-Cursor/lCursor",
  "o:hor50-Cursor/lCursor",
  "sm:block-Cursor/lCursor-blinkwait175-blinkoff150-blinkon175",
}

-- Neovim reads these as plain yaml, so their language servers would never start.
local function in_chart(ft)
  return function(path)
    return vim.fs.root(path, "Chart.yaml") and ft or nil
  end
end

vim.filetype.add {
  filename = {
    ["compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["docker-compose.yml"] = "yaml.docker-compose",
  },
  pattern = {
    -- priority: a template named values-*.yaml is still a template
    [".*/templates/.*%.ya?ml"] = { in_chart "helm", { priority = 1 } },
    [".*/templates/.*%.tpl"] = in_chart "helm",
    [".*/values.*%.ya?ml"] = in_chart "yaml.helm-values",
    [".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
  },
}
-- Those compound filetypes still highlight with the yaml parser.
vim.treesitter.language.register("yaml", { "yaml.docker-compose", "yaml.helm-values", "yaml.ansible" })
