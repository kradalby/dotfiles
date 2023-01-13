require "colorizer".setup()
require("neodev").setup()
require("mason").setup()
local lspconfig = require "lspconfig"

-- require("mason-lspconfig").setup {
--     ensure_installed = {
--         "ansiblels",
--         "bashls",
--         "cssls",
--         "cssmodules_ls",
--         "diagnosticls",
--         "dockerls",
--         "dotls",
--         "efm",
--         "elmls",
--         "golangci_lint_ls",
--         "gopls",
--         "graphql",
--         "html",
--         "jedi_language_server",
--         "jsonls",
--         "jsonnet_ls",
--         "pylsp",
--         "pyright",
--         "rnix",
--         "rust_analyzer",
--         -- "sourcekit",
--         "sumneko_lua",
--         "tailwindcss",
--         "taplo",
--         "terraformls",
--         "tflint",
--         "tsserver",
--         "vimls",
--         "vuels",
--         "yamlls",
--     },
-- }


require("mason-lspconfig").setup_handlers {
    function(server_name)
        lspconfig[server_name].setup {}
    end,
    ["jsonls"] = function()
        lspconfig.jsonls.setup {
            settings = {
                json = {
                    schemas = require("schemastore").json.schemas(),
                },
            },
        }
    end,
    -- ["rust_analyzer"] = function()
    --     require("rust-tools").setup {
    --         tools = {
    --             autoSetHints = false,
    --             executor = require("rust-tools/executors").toggleterm,
    --             hover_actions = { border = "solid" },
    --         },
    --     }
    -- end,
    ["sumneko_lua"] = function()
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
    end,
    ["gopls"] = function()
        lspconfig.gopls.setup {
            settings = {
                gopls = {
                    buildFlags = { "-tags=integration" }
                }
            }
        }
    end,
    ["yamlls"] = function()
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
    end,

    ["ansiblels"] = function()
        lspconfig.ansiblels.setup {
            filetypes = { "yaml", "yaml.ansible", "ansible" },
            root_dir = function(fname)
                return lspconfig.util.root_pattern { "requirements.yaml", "inventory" } (fname)
            end
        }
    end,

    ["efm"] = function()
        local home = os.getenv("HOME")
        -- local installer_server = require("nvim-lsp-installer.server")
        -- local go = require("nvim-lsp-installer.core.managers.go")
        local efm = require "efm"

        -- local root_dir = installer_server.get_server_root_path("efm")

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
    end,
}

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

require("mason-null-ls").setup({
    automatic_installation = true,
})

local cmp = require "cmp"
cmp.setup(
    {
        snippet = {
            expand = function(args)
                vim.fn["vsnip#anonymous"](args.body)
            end
        },
        sources = {
            { name = "nvim_lsp" },
            { name = "nvim_lsp_signature_help" },
            { name = "path" },
            { name = "buffer" },
            { name = "rg", option = { debounce = 500 } },
            -- {name = "treesitter"},
            { name = "vsnip" }
        },
        formatting = {
            format = require("lspkind").cmp_format(
                {
                    with_text = true,
                    maxwidth = 80,
                    menu = ({
                        buffer = "[Buffer]",
                        nvim_lsp = "[LSP]",
                        luasnip = "[LuaSnip]",
                        nvim_lua = "[Lua]",
                        latex_symbols = "[Latex]"
                    })
                }
            )
        },
        mapping = cmp.mapping.preset.insert({
            ["<CR>"] = cmp.mapping.confirm(
                {
                    behavior = cmp.ConfirmBehavior.Replace,
                    select = true
                }
            )
        })
    }
)

-- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(
    "/",
    {
        sources = {
            { name = "buffer" }
        }
    }
)

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(
    ":",
    {
        sources = cmp.config.sources(
            {
                { name = "path" }
            },
            {
                { name = "cmdline" }
            }
        )
    }
)

cmp.setup.cmdline {
    mapping = cmp.mapping.preset.cmdline({
    })

}

cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
        { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
    }, {
        { name = 'buffer' },
    })
})

require("nvim-autopairs").setup({})

require('lspsaga').setup({})
-- require "lspsaga".init_lsp_saga {
--     finder_action_keys = {
--         open = "o",
--         vsplit = "v",
--         -- split = "i",
--         quit = "q",
--         scroll_down = "<C-f>",
--         scroll_up = "<C-b>"
--     }
-- }

require("mini.indentscope").setup({})
require("mini.starter").setup({})
require("neoclip").setup(
    {
        enable_persistent_history = true,
    }
)
require("Comment").setup()
require("gitsigns").setup()
require("trouble").setup {}
-- TODO: This can hopefully go away when issue 10 is resolved.
require("todo-comments").setup {
    highlight = {
        before = "", -- "fg" or "bg" or empty
        keyword = "bg", -- "fg", "bg", "wide" or empty. (wide is the same as bg, but will also highlight surrounding characters)
        after = "fg", -- "fg" or "bg" or empty
        pattern = [[.*<(KEYWORDS)(\([^\)]*\))?:]],
        comments_only = true, -- uses treesitter to match keywords in comments only
        max_line_len = 400, -- ignore lines longer than this
        exclude = {} -- list of file types to exclude highlighting
    },
    search = {
        command = "rg",
        args = {
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column"
        },
        pattern = [[\b(KEYWORDS)(\([^\)]*\))?:]]
    }
}

require("dap").setup()
require("dap-go").setup()
require("dapui").setup()
