local execute = vim.api.nvim_command
local fn = vim.fn

local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

if fn.empty(fn.glob(install_path)) > 0 then
    Packer_bootstrap =
        fn.system(
        {
            "git",
            "clone",
            "--depth",
            "1",
            "https://github.com/wbthomason/packer.nvim",
            install_path
        }
    )
end

vim.cmd [[packadd packer.nvim]]
vim.cmd "autocmd BufWritePost plugins.lua PackerCompile"

return require("packer").startup(
    function(use)
        use "wbthomason/packer.nvim"

        use {
            "nvim-treesitter/nvim-treesitter",
            run = ":TSUpdate",
            requires = {"p00f/nvim-ts-rainbow"},
            config = function()
                require "nvim-treesitter.configs".setup {
                    ensure_installed = "maintained",
                    -- ignore_install =
                    --   {"haskell"}, -- Haskell breaks without Java?
                    highlight = {enable = true},
                    rainbow = {
                        enable = true,
                        extended_mode = true,
                        max_file_lines = 1000
                    }
                }
            end
        }

        use {
            "norcalli/nvim-colorizer.lua",
            config = function()
                require "colorizer".setup()
            end
        }

        use {
            "neovim/nvim-lspconfig",
            requires = {
                "nvim-lua/lsp-status.nvim",
                "williamboman/nvim-lsp-installer"
            }
        }
        use {
            "b0o/schemastore.nvim"
            -- ft = {"json", "yaml", "yaml.ansible"}
        }

        use {
            "hrsh7th/nvim-cmp",
            config = function()
                local cmp = require "cmp"
                cmp.setup(
                    {
                        snippet = {
                            expand = function(args)
                                vim.fn["vsnip#anonymous"](args.body)
                            end
                        },
                        sources = {
                            {name = "nvim_lsp"},
                            {name = "nvim_lsp_signature_help"},
                            {name = "path"},
                            {name = "buffer"},
                            {name = "rg", option = {debounce = 500}},
                            -- {name = "treesitter"},
                            {name = "vsnip"}
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
                        mapping = {
                            ["<CR>"] = cmp.mapping.confirm(
                                {
                                    behavior = cmp.ConfirmBehavior.Replace,
                                    select = true
                                }
                            )
                        }
                    }
                )

                -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
                cmp.setup.cmdline(
                    "/",
                    {
                        sources = {
                            {name = "buffer"}
                        }
                    }
                )

                -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
                cmp.setup.cmdline(
                    ":",
                    {
                        sources = cmp.config.sources(
                            {
                                {name = "path"}
                            },
                            {
                                {name = "cmdline"}
                            }
                        )
                    }
                )
            end,
            requires = {
                "hrsh7th/cmp-buffer",
                "hrsh7th/cmp-nvim-lsp",
                "hrsh7th/cmp-path",
                "hrsh7th/cmp-vsnip",
                "hrsh7th/cmp-cmdline",
                "hrsh7th/cmp-nvim-lsp-signature-help",
                "hrsh7th/vim-vsnip",
                "lukas-reineke/cmp-rg",
                "onsails/lspkind-nvim"
                -- "ray-x/cmp-treesitter"
            }
        }

        use {
            "jose-elias-alvarez/null-ls.nvim",
            config = function()
                local null_ls = require("null-ls")
                null_ls.setup(
                    {
                        sources = {
                            null_ls.builtins.code_actions.statix,
                            null_ls.builtins.diagnostics.editorconfig_checker.with(
                                {
                                    command = "editorconfig-checker"
                                }
                            ),
                            null_ls.builtins.diagnostics.gitlint,
                            null_ls.builtins.diagnostics.shellcheck,
                            null_ls.builtins.diagnostics.statix,
                            null_ls.builtins.formatting.fish_indent,
                            null_ls.builtins.formatting.shellharden,
                            null_ls.builtins.formatting.trim_newlines,
                            null_ls.builtins.formatting.trim_whitespace
                        }
                    }
                )
            end,
            requires = {
                use "nvim-lua/plenary.nvim"
            }
        }

        use {
            "bennypowers/nvim-regexplainer",
            config = function()
                require "regexplainer".setup(
                    {
                        auto = true
                    }
                )
            end,
            requires = {
                "nvim-lua/plenary.nvim",
                "MunifTanjim/nui.nvim"
            }
        }

        use {
            "windwp/nvim-autopairs",
            config = function()
                require("nvim-autopairs").setup({})
            end
        }

        -- use {
        --     "ray-x/lsp_signature.nvim",
        --     config = function()
        --         require "lsp_signature".on_attach()
        --     end
        -- }

        use {
            -- "glepnir/lspsaga.nvim",
            "tami5/lspsaga.nvim",
            config = function()
                require "lspsaga".init_lsp_saga {
                    finder_action_keys = {
                        open = "o",
                        vsplit = "v",
                        -- split = "i",
                        quit = "q",
                        scroll_down = "<C-f>",
                        scroll_up = "<C-b>"
                    }
                }
            end
        }

        use {
            "echasnovski/mini.nvim",
            config = function()
                require("mini.indentscope").setup({})
                require("mini.starter").setup({})
            end
        }

        -- use {
        --     "kosayoda/nvim-lightbulb",
        --     disable = true
        -- }

        use {"folke/lua-dev.nvim"}
        use {"darfink/vim-plist", ft = {"plist", "xml"}}

        use "kyazdani42/nvim-web-devicons"
        use "folke/tokyonight.nvim"
        -- use "tanvirtin/monokai.nvim"
        -- use "sainnhe/sonokai"
        -- use "savq/melange"

        -- use {
        --     "nvim-telescope/telescope.nvim",
        --     requires = {
        --         use "nvim-lua/popup.nvim",
        --         use "nvim-lua/plenary.nvim"
        --     }
        -- }

        use {
            "AckslD/nvim-neoclip.lua",
            requires = {
                {"tami5/sqlite.lua", module = "sqlite"},
                {"ibhagwan/fzf-lua"}
            },
            config = function()
                require("neoclip").setup(
                    {
                        enable_persistent_history = true
                    }
                )
            end
        }

        use {
            "ibhagwan/fzf-lua",
            requires = {
                "vijaymarupudi/nvim-fzf",
                "kyazdani42/nvim-web-devicons"
            }
        }

        use {
            "numToStr/Comment.nvim",
            config = function()
                require("Comment").setup()
            end
        }

        use {
            "lewis6991/gitsigns.nvim",
            requires = {
                "nvim-lua/plenary.nvim"
            },
            config = function()
                require("gitsigns").setup()
            end
        }

        -- Filetypes
        use "sheerun/vim-polyglot"

        -- Github integration
        use {
            "pwntester/octo.nvim",
            cond = function()
                return vim.fn.executable "gh" == 1
            end
        }

        use {
            "folke/trouble.nvim",
            requires = {
                "kyazdani42/nvim-web-devicons"
            },
            config = function()
                require("trouble").setup {}
            end
        }

        use {
            "folke/todo-comments.nvim",
            config = function()
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
            end
        }

        use {
            "andweeb/presence.nvim",
            cond = function()
                return vim.fn.has("macunix")
            end,
            config = function()
                require "presence":setup(
                    {
                        auto_update = true,
                        log_level = nil
                    }
                )
            end
        }

        use {
            "danymat/neogen",
            config = function()
                require("neogen").setup {
                    enabled = true
                }
            end,
            requires = "nvim-treesitter/nvim-treesitter"
        }

        -- Remove when nvim 12587 is resolved
        use "antoinemadec/FixCursorHold.nvim"

        if Packer_bootstrap then
            require("packer").sync()
        end
    end
)
