local cmp = require("cmp")
cmp.setup(
    {
        preselect = cmp.PreselectMode.Item,
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
            { name = "git" },
            { name = "emoji" },
            -- { name = "rg", option = { debounce = 500 } },
            -- {name = "treesitter"},
            -- { name = "vsnip" }
        },
        -- formatting = {
        --     fields = { 'abbr', 'kind', 'menu' },
        --     format = require("lspkind").cmp_format(
        --         {
        --             with_text = true,
        --             maxwidth = 80,
        --             menu = ({
        --                 buffer = "[Buffer]",
        --                 nvim_lsp = "[LSP]",
        --                 luasnip = "[LuaSnip]",
        --                 nvim_lua = "[Lua]",
        --                 latex_symbols = "[Latex]"
        --             })
        --         }
        --     )
        -- },
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

-- cmp.setup.filetype('gitcommit', {
--     sourcs = cmp.config.sources({
--         { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
--     }, {
--         { name = 'buffer' },
--     })
-- })

require("cmp_git").setup()
