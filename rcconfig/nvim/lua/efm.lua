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
    formatCommand = "golines --max-len=120 --base-formatter=gofumpt",
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

M.languages = {
    python = {M.isort, M.flake8, M.black, M.mypy},
    lua = {M.luafmt},
    json = {M.jq, M.prettier},
    html = {M.prettier},
    xml = {M.prettier},
    css = {M.prettier},
    markdown = {M.prettier},
    go = {M.golines, M.golangci},
    sh = {M.shfmt, M.shellcheck},
    yaml = {M.yamllint, M.prettier},
    ["yaml.ansible"] = {M.yamllint, M.prettier}
}

return M
