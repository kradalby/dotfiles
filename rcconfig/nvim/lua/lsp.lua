local lsp_installer = require "nvim-lsp-installer"
local lspconfig = require "lspconfig"
local lsp_status = require "lsp-status"
lsp_status.register_progress()

local snippet_capabilities = {
    textDocument = {completion = {completionItem = {snippetSupport = true}}}
}

local function install_missing_servers()
    local lsps = {
        "bashls",
        "cssls",
        "dockerls",
        "elmls",
        "eslintls",
        "gopls",
        "html",
        "jsonls",
        "omnisharp",
        "pyright",
        "rust_analyzer",
        "sumneko_lua",
        "tailwindcss",
        "terraformls",
        "tsserver",
        "vimls",
        "yamlls"
    }

    for _, lsp_name in ipairs(lsps) do
        local ok, lsp = lsp_installer.get_server(lsp_name)
        if ok then
            if not lsp:is_installed() then
                lsp:install()
            end
        end
    end
end

local function common_on_attach(client)
    lsp_status.on_attach(client)
end

install_missing_servers()
local installed_servers = lsp_installer.get_installed_servers()

-- Servers not controlled by lsp_installer
table.insert(installed_servers, lspconfig["sourcekit"])
table.insert(installed_servers, lspconfig["groovyls"])
table.insert(installed_servers, lspconfig["tflint"])
table.insert(installed_servers, lspconfig["pyls"])

for _, server in pairs(installed_servers) do
    local capabilities =
        vim.tbl_deep_extend(
        "keep",
        vim.lsp.protocol.make_client_capabilities(),
        lsp_status.capabilities,
        snippet_capabilities
    )

    local opts = {
        on_attach = common_on_attach,
        capabilities = capabilities
    }

    -- (optional) Customize the options passed to the server
    -- if server.name == "tsserver" then
    --     opts.root_dir = function() ... end
    -- end

    server:setup(opts)
end
