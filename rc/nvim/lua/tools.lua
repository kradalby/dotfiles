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
    -- "vscode-langservers-extracted",
    "vuels",
    "jsonnet_ls",
    "sourcekit",
    -- "fsautocomplete",
    "yamlls",
    "cssmodules_ls",
    "rnix"
    -- "groovyls"
    -- "sqlls",
    -- "sqls",
}

function table.empty(self)
    for _, _ in pairs(self) do
        return false
    end
    return true
end

local M = {}

function M.install_servers()
    local lsps = {}

    for _, lsp_name in ipairs(Lsps) do
        local ok, lsp_server = lsp_installer.get_server(lsp_name)
        if ok then
            if not lsp_server:is_installed() then
                table.insert(lsps, lsp_name)
            end
        end
    end

    if not table.empty(lsps) then
        print("Installing ", lsps)
        lsp_installer.install_sync(lsps)
        print("Installed ", lsps)
    else
        print("All servers are already installed")
    end
end

function M.install_servers_gui()
    local lsps = {}

    for _, lsp_name in ipairs(Lsps) do
        local ok, lsp_server = lsp_installer.get_server(lsp_name)
        if ok then
            if not lsp_server:is_installed() then
                print("Installing ", lsp)
                lsp_installer.install(lsp_name)
                print("Installed ", lsp)
            end
        end
    end

end

return M
