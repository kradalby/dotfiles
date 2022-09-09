local lsp_installer = require "nvim-lsp-installer"
local lspconfig = require "lspconfig"
local util = require "lspconfig/util"
local lsp_status = require "lsp-status"
local efm = require "efm"
lsp_status.register_progress()

local function enable_auto_format()
    vim.api.nvim_command [[augroup Format]]
    vim.api.nvim_command [[autocmd! * <buffer>]]
    vim.api.nvim_command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
    vim.api.nvim_command [[augroup END]]
end

local function enable_code_action_lightbulb()
    -- This broke in Blink on the iPad
    --vim.api.nvim_command [[autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()]]
end

local function common_on_attach(client)
    if client.resolved_capabilities.document_formatting then
        enable_auto_format()
    end

    if client.resolved_capabilities.code_action then
        enable_code_action_lightbulb()
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


    if server.name == "efm" then
        local home = os.getenv("HOME")
        local installer_server = require("nvim-lsp-installer.server")
        local go = require("nvim-lsp-installer.core.managers.go")

        local root_dir = installer_server.get_server_root_path("efm")

        opts.default_options = {
            cmd_env = go.env(root_dir),
            cmd = {
                "efm-langserver",
                "-logfile",
                home .. "/.config/efm-langserver/efm.log",
                "-loglevel",
                "1"
            }
        }

        opts.flags = { debounce_text_changes = 2000 }
        opts.root_dir = lspconfig.util.root_pattern(".git", ".")
        opts.filetypes = vim.tbl_keys(efm.languages)
        opts.init_options = {
            documentFormatting = true,
            document_formatting = true,
            documentSymbol = true,
            codeAction = true
        }
        opts.settings = {
            lintDebounce = "1000ms",
            formatDebounce = "1000ms",
            rootMarkers = { ".git/" },
            languages = efm.languages
        }
        opts.on_attach = function(client)
            client.resolved_capabilities.document_formatting = true
            client.resolved_capabilities.goto_definition = false
            -- client.resolved_capabilities.code_action = false
            common_on_attach(client)
        end
    end

    if server.name == "sumneko_lua" then
        opts = vim.tbl_deep_extend("keep", opts, require("lua-dev").setup({}))
    end

    server:setup(opts)
    vim.cmd [[ do User LspAttachBuffers ]]
end

lsp_installer.on_server_ready(common_lsp)

local servers = {}
for _, lsp in ipairs(servers) do
    common_lsp(lspconfig[lsp])
end
