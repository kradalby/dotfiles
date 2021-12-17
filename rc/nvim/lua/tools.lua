local lsp_installer = require "nvim-lsp-installer"

Lsps = {
    "ansiblels",
    "bashls",
    "cssls",
    "diagnosticls",
    "dockerls",
    "dotls",
    "efm",
    "elmls",
    "gopls",
    "graphql",
    -- "html",
    "jedi_language_server",
    "jsonls",
    "kotlin_language_server",
    "omnisharp",
    "pylsp",
    "pyright",
    "rescriptls",
    "rust_analyzer",
    "sumneko_lua",
    "tailwindcss",
    "terraformls",
    "tflint",
    "tsserver",
    "vimls",
    "vscode-langservers-extracted",
    "vuels",
    "jsonnet_ls",
    "sourcekit",
    -- "fsautocomplete",
    "yamlls",
    "cssmodules_ls"
    -- "groovyls"
    -- "sqlls",
    -- "sqls",
}

local M = {}

function M.install_servers()
    lsp_installer.install_sync(Lsps)
end

return M
