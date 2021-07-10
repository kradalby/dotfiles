local lsp_installer = require "nvim-lsp-installer"
local lspconfig = require "lspconfig"
local lsp_status = require "lsp-status"
lsp_status.register_progress()

-- function Install_servers(servers)
--     for _, server in pairs(servers) do
--         require "lspinstall".install_server_no_prompt(server)
--     end
-- end

-- Install with:
-- :lua Install_servers(Lsps)
-- Lsps = {
--     "go",
--     "elm",
--     "css",
--     "bash",
--     "dockerfile",
--     "html",
--     "json",
--     "lua",
--     "python",
--     "rust",
--     "terraform",
--     "typescript",
--     "tailwindcss",
--     "yaml"
-- }

-- lsp-install
-- Servers available in:
-- ~/.local/share/nvim/site/pack/paqs/start/nvim-lspinstall/lua/lspinstall/servers.lua
-- local function setup_servers()
--     require "lspinstall".setup()
--
--     -- get all installed servers
--     local servers = require "lspinstall".installed_servers()
--     -- ... and add manually installed servers
--     table.insert(servers, "clangd")
--     table.insert(servers, "sourcekit")
--     table.insert(servers, "groovyls")
--     table.insert(servers, "tflint")
--     table.insert(servers, "pyls")
--
--     for _, server in pairs(servers) do
--         local capabilities =
--             vim.tbl_deep_extend(
--             "keep",
--             vim.lsp.protocol.make_client_capabilities(),
--             lsp_status.capabilities,
--             snippet_capabilities
--         )
--         local config = {
--             capabilities = capabilities,
--             on_attach = on_attach
--         }
--
--         -- language specific config
--         if server == "tailwindcss" then
--             local override = {
--                 filetypes = {"swift"},
--                 settings = {
--                     tailwindCSS = {
--                         experimental = {
--                             classRegex = {
--                                 {"\\.class\\(([^)]*)\\)", '"([^\']*)"', '"([^\']*)"'}
--                             }
--                         }
--                     }
--                 }
--             }
--             config = vim.tbl_deep_extend("keep", config, override)
--         end
--
--         if server == "lua" then
--             local override = {
--                 settings = {
--                     Lua = {
--                         diagnostics = {
--                             globals = {"vim"}
--                         }
--                     }
--                 }
--             }
--             config = vim.tbl_deep_extend("keep", config, override)
--         end
--         -- if server == "sourcekit" then
--         --     config.filetypes = {"swift", "objective-c", "objective-cpp"} -- we don't want c and cpp!
--         -- end
--         -- if server == "clangd" then
--         --     config.filetypes = {"c", "cpp"} -- we don't want objective-c and objective-cpp!
--         -- end
--
--         require "lspconfig"[server].setup(config)
--     end
-- end
--
-- setup_servers()

-- Automatically reload after `:LspInstall <server>` so we don't have to restart neovim
-- require "lspinstall".post_install_hook = function()
--     setup_servers() -- reload installed servers
--     vim.cmd("bufdo e") -- this triggers the FileType autocmd that starts the server
-- end

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
