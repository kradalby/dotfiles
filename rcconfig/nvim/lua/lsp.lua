local lsp_status = require("lsp-status")
lsp_status.register_progress()

local function on_attach(client)
    lsp_status.on_attach(client)
end

function install_servers(servers)
    for _, server in pairs(servers) do
        require "lspinstall".install_server_no_prompt(server)
    end
end

-- Install with:
-- :lua install_servers(lsps)
lsps = {
    "go",
    "elm",
    "css",
    "bash",
    "dockerfile",
    "html",
    "json",
    "lua",
    "python",
    "rust",
    "terraform",
    "typescript",
    "tailwindcss",
    "yaml"
}

local snippet_capabilities = {
    textDocument = {completion = {completionItem = {snippetSupport = true}}}
}

-- lsp-install
-- Servers available in:
-- ~/.local/share/nvim/site/pack/paqs/start/nvim-lspinstall/lua/lspinstall/servers.lua
local function setup_servers()
    require "lspinstall".setup()

    -- get all installed servers
    local servers = require "lspinstall".installed_servers()
    -- ... and add manually installed servers
    table.insert(servers, "clangd")
    table.insert(servers, "sourcekit")
    table.insert(servers, "groovyls")
    table.insert(servers, "tflint")
    table.insert(servers, "pyls")

    for _, server in pairs(servers) do
        local capabilities =
            vim.tbl_deep_extend(
            "keep",
            vim.lsp.protocol.make_client_capabilities(),
            lsp_status.capabilities,
            snippet_capabilities
        )
        local config = {
            capabilities = capabilities,
            on_attach = on_attach
        }

        -- language specific config
        if server == "tailwindcss" then
            local override = {
                filetypes = {"swift"},
                settings = {
                    tailwindCSS = {
                        experimental = {
                            classRegex = {
                                {"\\.class\\(([^)]*)\\)", '"([^\']*)"', '"([^\']*)"'}
                            }
                        }
                    }
                }
            }
            config = vim.tbl_deep_extend("keep", config, override)
        end
        -- if server == "sourcekit" then
        --     config.filetypes = {"swift", "objective-c", "objective-cpp"} -- we don't want c and cpp!
        -- end
        -- if server == "clangd" then
        --     config.filetypes = {"c", "cpp"} -- we don't want objective-c and objective-cpp!
        -- end

        require "lspconfig"[server].setup(config)
    end
end

setup_servers()

-- Automatically reload after `:LspInstall <server>` so we don't have to restart neovim
require "lspinstall".post_install_hook = function()
    setup_servers() -- reload installed servers
    vim.cmd("bufdo e") -- this triggers the FileType autocmd that starts the server
end
