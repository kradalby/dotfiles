require("neodev").setup()
local lspconfig = require "lspconfig"

require('lspsaga').setup({})

local null_ls = require("null-ls")
null_ls.setup(
    {
        on_attach = function(client, bufnr)
            if client.supports_method("textDocument/formatting") then
                vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
                vim.api.nvim_create_autocmd("BufWritePre", {
                    group = augroup,
                    buffer = bufnr,
                    callback = function()
                        -- on 0.8, you should use vim.lsp.buf.format({ bufnr = bufnr }) instead
                        vim.lsp.buf.format()
                    end,
                })
            end
        end,
        sources = {
            null_ls.builtins.code_actions.eslint_d,
            null_ls.builtins.code_actions.proselint,
            null_ls.builtins.code_actions.shellcheck,
            null_ls.builtins.code_actions.statix,
            null_ls.builtins.completion.spell,
            null_ls.builtins.diagnostics.editorconfig_checker.with(
                {
                    command = "editorconfig-checker"
                }
            ),
            null_ls.builtins.diagnostics.actionlint,
            null_ls.builtins.diagnostics.commitlint,
            null_ls.builtins.diagnostics.curlylint,
            null_ls.builtins.diagnostics.deadnix,
            null_ls.builtins.diagnostics.djlint,
            null_ls.builtins.diagnostics.eslint_d,
            null_ls.builtins.diagnostics.fish,
            null_ls.builtins.diagnostics.gitlint,
            null_ls.builtins.diagnostics.hadolint,
            null_ls.builtins.diagnostics.proselint,
            null_ls.builtins.diagnostics.pylama,
            null_ls.builtins.diagnostics.shellcheck,
            null_ls.builtins.diagnostics.staticcheck,
            null_ls.builtins.diagnostics.statix,
            null_ls.builtins.diagnostics.vale,
            null_ls.builtins.diagnostics.write_good,
            null_ls.builtins.diagnostics.tidy,
            null_ls.builtins.formatting.alejandra,
            null_ls.builtins.formatting.beautysh,
            null_ls.builtins.formatting.black,
            null_ls.builtins.formatting.cbfmt,
            null_ls.builtins.formatting.clang_format,
            null_ls.builtins.formatting.djlint,
            null_ls.builtins.formatting.eslint_d,
            null_ls.builtins.formatting.fish_indent,
            null_ls.builtins.formatting.goimports.with({
                condition = function(utils)
                    -- Try to detect if we are in a tailscale repo
                    return utils.root_has_file({ "go.toolchain.rev" })
                end,
            }),
            null_ls.builtins.formatting.golines.with({
                condition = function(utils)
                    return not utils.root_has_file({ "go.toolchain.rev" })
                end,
            }),
            null_ls.builtins.formatting.isort,
            null_ls.builtins.formatting.jq,
            null_ls.builtins.formatting.tidy,
            null_ls.builtins.formatting.prettierd,
            null_ls.builtins.formatting.shellharden,
            null_ls.builtins.formatting.swiftformat,
            -- null_ls.builtins.formatting.terraform_fmt, -- Covered by LSP?
            null_ls.builtins.formatting.trim_newlines,
            null_ls.builtins.formatting.trim_whitespace,
            null_ls.builtins.formatting.packer,
            null_ls.builtins.hover.dictionary
        }
    }
)


lspconfig.jsonls.setup {
    settings = {
        json = {
            schemas = require("schemastore").json.schemas(),
        },
    },
}

lspconfig.sumneko_lua.setup({
    settings = {
        Lua = {
            format = {
                enable = false,
            },
            hint = {
                enable = true,
                arrayIndex = "Disable", -- "Enable", "Auto", "Disable"
                await = true,
                paramName = "Disable", -- "All", "Literal", "Disable"
                paramType = false,
                semicolon = "Disable", -- "All", "SameLine", "Disable"
                setType = true,
            },
            diagnostics = {
                globals = { "P" },
            },
        },
    },
})
lspconfig.gopls.setup {
    settings = {
        gopls = {
        }
    }
}

lspconfig.yamlls.setup {
    filetypes = {
        "yaml", "yaml.ansible", "ansible"
    },
    settings = {
        yaml = {
            hover = true,
            completion = true,
            validate = true,
            schemas = require("schemastore").json.schemas(),
        },
    },
}

lspconfig.ansiblels.setup {
    filetypes = { "yaml", "yaml.ansible", "ansible" },
    root_dir = function(fname)
        return lspconfig.util.root_pattern { "requirements.yaml", "inventory" } (fname)
    end
}

local home = os.getenv("HOME")
local efm = require "efm"
lspconfig.efm.setup {
    default_options = {
        -- cmd_env = go.env(root_dir),
        cmd = {
            "efm-langserver",
            "-logfile",
            home .. "/.config/efm-langserver/efm.log",
            "-loglevel",
            "1"
        }
    },

    flags = { debounce_text_changes = 2000 },
    root_dir = lspconfig.util.root_pattern(".git", "."),
    filetypes = vim.tbl_keys(efm.languages),
    init_options = {
        documentFormatting = true,
        document_formatting = true,
        documentSymbol = true,
        codeAction = true
    },

    settings = {
        lintDebounce = "1000ms",
        formatDebounce = "1000ms",
        rootMarkers = { ".git/" },
        languages = efm.languages
    },

    on_attach = function(client)
        client.server_capabilities.document_formatting = true
        client.server_capabilities.goto_definition = false
        -- client.server_capabilities.code_action = false
        -- common_on_attach(client)
    end
}


lspconfig.nil_ls.setup {}
lspconfig.rnix.setup {}
