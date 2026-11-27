require("conform").setup({
  formatters_by_ft = {
    -- Nix
    nix = { "nixfmt" },

    -- Python: ruff handles both import sorting and formatting
    python = { "ruff_fix", "ruff_format" },

    -- Go: conditional goimports + golines
    go = function(bufnr)
      local formatters = {}
      -- Only use goimports in repos that have a go.toolchain.rev file
      local go_toolchain = vim.fs.find("go.toolchain.rev", {
        upward = true,
        path = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)),
      })
      if #go_toolchain > 0 then
        table.insert(formatters, "goimports")
      end
      table.insert(formatters, "golines")
      return formatters
    end,

    -- Protobuf
    proto = { "buf" },

    -- Markdown: cbfmt for code blocks
    markdown = { "cbfmt" },

    -- C/C++
    c = { "clang-format" },
    cpp = { "clang-format" },

    -- Django/Jinja templates
    htmldjango = { "djlint" },

    -- Fish shell
    fish = { "fish_indent" },

    -- JSON
    json = { "jq" },
    jsonc = { "jq" },

    -- JS/TS/HTML/CSS: prettierd with prettier as fallback
    javascript = { "prettierd", "prettier", stop_after_first = true },
    javascriptreact = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    typescriptreact = { "prettierd", "prettier", stop_after_first = true },
    html = { "prettierd", "prettier", stop_after_first = true },
    css = { "prettierd", "prettier", stop_after_first = true },
    scss = { "prettierd", "prettier", stop_after_first = true },
    less = { "prettierd", "prettier", stop_after_first = true },
    vue = { "prettierd", "prettier", stop_after_first = true },
    graphql = { "prettierd", "prettier", stop_after_first = true },

    -- Shell: shellharden first (fixes quoting), then shfmt (formats)
    sh = { "shellharden", "shfmt" },
    bash = { "shellharden", "shfmt" },

    -- Swift
    swift = { "swiftformat" },

    -- HCL (Packer/Terraform)
    hcl = { "packer_fmt" },
    packer = { "packer_fmt" },

    -- XML via tidy
    xml = { "tidy" },
  },

  -- Format on save
  format_on_save = {
    timeout_ms = 500,
    lsp_format = "fallback",
  },

  -- Custom formatter definitions for tools not built into conform
  formatters = {
    tidy = {
      command = "tidy",
      args = {
        "-quiet",
        "-xml",
        "--indent",
        "auto",
        "--indent-spaces",
        "2",
        "--wrap",
        "80",
        "--sort-attributes",
        "alpha",
        "--tidy-mark",
        "no",
      },
      stdin = true,
      exit_codes = { 0, 1 },
    },
  },
})

-- Set formatexpr for gq operator
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

-- Manual format keymap
vim.keymap.set("n", "<leader>ff", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })
