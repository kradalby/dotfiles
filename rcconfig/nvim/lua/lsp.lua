local lsp_installer = require "nvim-lsp-installer"
local lspconfig = require "lspconfig"
local util = require "lspconfig/util"
local lsp_status = require "lsp-status"
local coq = require "coq"
local efm = require "efm"
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
        "omnisharp",
        "rescriptls",
        "kotlin_language_server",
        "pylsp",
        "diagnosticls"
        -- "groovyls"
    }

    for _, lsp_name in ipairs(lsps) do
        local ok, lsp_server = lsp_installer.get_server(lsp_name)
        if ok then
            if not lsp_server:is_installed() then
                lsp_installer.install(lsp_name)
            end
        end
    end
end

install_missing_servers()

local function common_on_attach(client)
    if client.resolved_capabilities.document_formatting then
        vim.api.nvim_command [[augroup Format]]
        vim.api.nvim_command [[autocmd! * <buffer>]]
        vim.api.nvim_command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
        vim.api.nvim_command [[augroup END]]
    end

    lsp_status.on_attach(client)
end

local installed_servers = lsp_installer.get_installed_servers()

-- Servers not controlled by lsp_installer
table.insert(installed_servers, lspconfig["sourcekit"])

lsp_installer.on_server_ready(
    function(server)
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

        if server.name == "efm" then
            local home = os.getenv("HOME")
            local installer_server = require "nvim-lsp-installer.server"
            local go = require "nvim-lsp-installer.installers.go"

            local root_dir = installer_server.get_server_root_path "efm"

            opts.cmd = {
                go.executable(root_dir, "efm-langserver"),
                "-logfile",
                home .. "/.config/efm-langserver/efm.log",
                "-loglevel",
                "1"
            }
            opts.root_dir = lspconfig.util.root_pattern(".git", ".")
            opts.filetypes = vim.tbl_keys(efm.languages)
            opts.init_options = {
                documentFormatting = true,
                codeAction = true,
                documentSymbol = true
            }
            opts.settings = {
                rootMarkers = {".git/"},
                languages = efm.languages
            }
        end

        if server.name == "yamlls" then
            opts.filetypes = {"yaml", "yaml.ansible", "ansible"}
        end

        if server.name == "sumneko_lua" then
            opts = vim.tbl_deep_extend("keep", opts, require("lua-dev").setup({}))
        end

        opts = coq.lsp_ensure_capabilities(opts)

        server:setup(opts)
        vim.cmd [[ do User LspAttachBuffers ]]
    end
)
