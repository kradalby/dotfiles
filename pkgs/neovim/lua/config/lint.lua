-- Register compound filetype for GitHub Actions YAML files
vim.filetype.add({
  pattern = {
    [".*/.github/workflows/.*%.yml"] = "yaml.ghaction",
    [".*/.github/workflows/.*%.yaml"] = "yaml.ghaction",
  },
})

local lint = require("lint")

lint.linters_by_ft = {
  -- GitHub Actions (compound filetype)
  ghaction = { "actionlint" },

  -- Docker
  dockerfile = { "hadolint" },

  -- Fish shell
  fish = { "fish" },

  -- Git
  gitcommit = { "gitlint" },

  -- HTML
  html = { "tidy" },

  -- Django templates
  htmldjango = { "djlint" },

  -- JavaScript / TypeScript
  javascript = { "eslint_d" },
  javascriptreact = { "eslint_d" },
  typescript = { "eslint_d" },
  typescriptreact = { "eslint_d" },

  -- Nix
  nix = { "deadnix", "statix" },

  -- Protobuf
  proto = { "buf_lint" },

  -- Python (ruff diagnostics come from the LSP server, mypy for type checking)
  python = { "mypy" },

  -- Shell
  sh = { "shellcheck" },
  bash = { "shellcheck" },

  -- CSS
  css = { "stylelint" },
  scss = { "stylelint" },
  less = { "stylelint" },

  -- Prose
  markdown = { "vale", "write_good" },

  -- YAML
  yaml = { "yamllint" },
}

-- Trigger linting on file read and write
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
  group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
  callback = function()
    lint.try_lint()
  end,
})

-- Run editorconfig-checker on write only (spawns external process)
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("nvim-lint-editorconfig", { clear = true }),
  callback = function()
    lint.try_lint("editorconfig-checker")
  end,
})
