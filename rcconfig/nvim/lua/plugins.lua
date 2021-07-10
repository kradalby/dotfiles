local execute = vim.api.nvim_command
local fn = vim.fn

local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({"git", "clone", "https://github.com/wbthomason/packer.nvim", install_path})
    execute "packadd packer.nvim"
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
                    ensure_installed = "all",
                    ignore_install = {"haskell"}, -- Haskell breaks without Java?
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
                -- "kabouzeid/nvim-lspinstall",
                -- "kradalby/nvim-lspinstall" -- TODO: remove when #83 is resolved
                "williamboman/nvim-lsp-installer"
            }
        }

        use {
            "hrsh7th/nvim-compe",
            config = function()
                require "compe".setup {
                    source = {
                        path = true,
                        buffer = true,
                        calc = true,
                        nvim_lsp = true,
                        nvim_lua = true,
                        treesitter = true
                    }
                }
            end
        }
        use {
            "ray-x/lsp_signature.nvim",
            config = function()
                require "lsp_signature".on_attach()
            end
        }

        use {
            "dense-analysis/ale"
            -- TODO: Only certain files?
        } -- TODO: Replace with Lua based plugin

        use "kyazdani42/nvim-web-devicons"
        use "tanvirtin/monokai.nvim"

        use "nvim-lua/popup.nvim"
        use "nvim-lua/plenary.nvim"
        use "nvim-telescope/telescope.nvim"

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
        if vim.fn.executable "gh" == 1 then
            use "pwntester/octo.nvim"
        end

        use {
            "folke/trouble.nvim",
            requires = "kyazdani42/nvim-web-devicons",
            config = function()
                require("trouble").setup {}
            end
        }

        use {
            "andweeb/presence.nvim",
            config = function()
                require "presence":setup(
                    {
                        auto_update = true,
                        log_level = nil
                    }
                )
            end
        }
    end
)
