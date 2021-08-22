local lsp_installer = require "nvim-lsp-installer"
local lspconfig = require "lspconfig"
local util = require "lspconfig/util"
local lsp_status = require "lsp-status"
local coq = require "coq"
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
        "yamlls",
        "pyright",
        "sqlls",
        "sqls",
        "vuels",
        "gopls",
        "ansiblels",
        "jedi_language_server",
        "tflint",
        "efm",
        "pylsp"
        -- "groovyls"
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
-- table.insert(installed_servers, lspconfig["groovyls"])
-- table.insert(installed_servers, lspconfig["pylsp"])
-- table.insert(installed_servers, lspconfig["jedi_language_server"])
-- table.insert(installed_servers, lspconfig["ansiblels"])
-- table.insert(installed_servers, lspconfig["tflint"])

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
    if server.name == "ansiblels" then
        opts.filetypes = {"yaml", "yaml.ansible", "ansible"}
        opts.root_dir = function(fname)
            -- return util.root_pattern {"requirements.yaml", "inventory", "*.yml", "*.yaml"}(fname)
            return util.root_pattern {"requirements.yaml", "inventory"}(fname)
        end
    -- server.setup(opts)
    end

    if server.name == "yamlls" then
        opts.filetypes = {"yaml", "yaml.ansible", "ansible"}
    end

    if server.name == "sumneko_lua" then
        opts = vim.tbl_deep_extend("keep", opts, require("lua-dev").setup({}))
    end

    opts = coq.lsp_ensure_capabilities(opts)

    server:setup(opts)
end
