local lsp_installer = require "nvim-lsp-installer"
local lspconfig = require "lspconfig"
local util = require "lspconfig/util"
local lsp_status = require "lsp-status"
-- local coq = require "coq"
local efm = require "efm"
lsp_status.register_progress()

local function install_missing_servers()
    local lsps = {
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
        "yamlls"
        -- "groovyls"
        -- "sqlls",
        -- "sqls",
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

local function common_lsp(server)
    local capabilities =
        require("cmp_nvim_lsp").update_capabilities(
        vim.tbl_deep_extend("keep", vim.lsp.protocol.make_client_capabilities(), lsp_status.capabilities)
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
            document_formatting = true,
            documentSymbol = true,
            codeAction = false
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

    -- opts = coq.lsp_ensure_capabilities(opts)

    server:setup(opts)
    vim.cmd [[ do User LspAttachBuffers ]]
end

lsp_installer.on_server_ready(common_lsp)

local servers = {"sourcekit"}
for _, lsp in ipairs(servers) do
    common_lsp(lspconfig[lsp])
end
