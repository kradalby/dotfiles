local M = {}

M.luafmt = {
    formatCommand = "luafmt --stdin",
    formatStdin = true
}

M.flake8 = {
    lintCommand = "flake8 --ignore=E501 --stdin-display-name ${INPUT} -",
    lintStdin = true,
    lintIgnoreExitCode = true,
    lintFormats = {"%f:%l:%c: %m"}
}

M.isort = {
    formatCommand = "isort -",
    formatStdin = true
}

M.autopep8 = {
    formatCommand = "autopep8 --ignore E501 -",
    formatStdin = true
}

M.black = {
    formatCommand = "black --quiet -",
    formatStdin = true
}

M.mypy = {
    lintCommand = "mypy --show-column-numbers --ignore-missing-imports",
    lintFormats = {"%f:%l:%c: %trror: %m", "%f:%l:%c: %tarning: %m", "%f:%l:%c: %tote: %m"}
}

M.prettier = {
    formatCommand = "prettier --stdin-filepath ${INPUT}",
    formatStdin = true
}

M.gofumpt = {
    formatCommand = "gofumpt",
    formatStdin = true
}

M.golines = {
    formatCommand = "golines --max-len=88 --base-formatter=gofumpt",
    formatStdin = true
}

M.golangci = {
    lintCommand = "golangci-lint run --fast"
}

M.shfmt = {
    formatCommand = "shfmt -ci -s -bn",
    formatStdin = true
}

M.yamllint = {
    lintCommand = "yamllint -f parsable -",
    lintStdin = true
}

M.shellcheck = {
    lintCommand = "shellcheck -f gcc -x",
    lintSource = "shellcheck",
    lintFormats = {
        "%f:%l:%c: %trror: %m",
        "%f:%l:%c: %tarning: %m",
        "%f:%l:%c: %tote: %m"
    }
}

M.jq = {
    lintCommand = "jq ."
}

M.stylelint = {
    lintCommand = "stylelint --stdin --stdin-filename ${INPUT} --formatter compact",
    lintIgnoreExitCode = true,
    lintStdin = true,
    lintFormats = {"%f: line %l, col %c, %tarning - %m", "%f: line %l, col %c, %trror - %m"},
    formatCommand = "stylelint --fix --stdin --stdin-filename ${INPUT}",
    formatStdin = true
}

M.eslint_d = {
    lintCommand = "eslint_d -f unix --stdin --stdin-filename ${INPUT} -f visualstudio",
    lintStdin = true,
    lintFormats = {"%f(%l,%c): %tarning %m", "%f(%l,%c): %rror %m"}, -- {"%f:%l:%c: %m"},
    lintIgnoreExitCode = true,
    formatCommand = "eslint_d --fix-to-stdout --stdin --stdin-filename=${INPUT}",
    formatStdin = true
}

M.rustfmt = {formatCommand = "rustfmt", formatStdin = true}

M.clangfmtproto = {
    formatCommand = [[clang-format -style="{BasedOnStyle: Google, IndentWidth: 4, AlignConsecutiveDeclarations: true, AlignConsecutiveAssignments: true, ColumnLimit: 0}"]],
    formatStdin = true
}

M.buf_lint = {
    prefix = "buif",
    lintCommand = "buf lint --path",
    rootMarkers = {"buf.yaml"}
}

M.languages = {
    python = {M.isort, M.flake8, M.black, M.mypy},
    lua = {M.luafmt},
    json = {M.jq, M.prettier},
    html = {M.prettier},
    svelte = {M.eslint_d, M.prettier},
    xml = {M.prettier},
    css = {M.prettier},
    typescript = {M.stylelint, M.prettier, M.eslint_d},
    typescriptreact = {M.stylelint, M.prettier, M.eslint_d},
    javascript = {M.eslint_d, M.prettier},
    javascriptreact = {M.eslint_d, M.prettier},
    sass = {M.prettier},
    less = {M.prettier},
    graphql = {M.prettier},
    vue = {M.prettier},
    scss = {M.prettier},
    markdown = {M.prettier},
    go = {M.golines, M.golangci},
    sh = {M.shfmt, M.shellcheck},
    yaml = {M.yamllint, M.prettier},
    ["yaml.ansible"] = {M.yamllint, M.prettier},
    proto = {M.clangfmtproto, M.buf_lint},
    rust = {M.rustfmt}
}

return M
