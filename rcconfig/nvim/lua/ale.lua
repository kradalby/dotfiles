local g = vim.g
g.ale_linters = {
    go = {"golangci-lint"},
    terraform = {"terraform", "tflint"},
    -- python = {"pylint", "flake8", "pyre", "mypy", "pyright"},
    python = {"pyre", "mypy", "pyright"},
    ansible = {"ansible-lint"},
    dockerfile = {"dockerfile_lint", "hadolint"},
    swift = {"apple-swift-format"},
    fish = {"fish_indent"}
}

g.ale_fixers = {
    javascript = {"prettier", "eslint"},
    typescript = {"prettier", "eslint"},
    elm = {"format"},
    sh = {"shfmt"},
    go = {"goimports"},
    terraform = {"terraform"},
    html = {"prettier"},
    css = {"prettier"},
    markdown = {"prettier"},
    scss = {"prettier"},
    json = {"prettier"},
    yaml = {"prettier"},
    fsharp = {"fantomas"},
    python = {"autoimport", "isort", "black"},
    lua = {"luafmt", "black"},
    swift = {"apple-swift-format"}
}
g.ale_fixers["*"] = {"remove_trailing_lines", "trim_whitespace"}

g.ale_fix_on_save = 1
g.ale_lint_on_save = 1
g.ale_completion_enabled = 0
g.ale_linters_explicit = 0
g.ale_python_flake8_options = "--max-line-length=88"
g.ale_go_golangci_lint_package = 1
