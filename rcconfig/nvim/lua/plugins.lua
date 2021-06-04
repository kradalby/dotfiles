local execute = vim.api.nvim_command
local fn = vim.fn

local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'

if fn.empty(fn.glob(install_path)) > 0 then
  fn.system({'git', 'clone', 'https://github.com/wbthomason/packer.nvim', install_path})
  execute 'packadd packer.nvim'
end

vim.cmd [[packadd packer.nvim]]
vim.cmd 'autocmd BufWritePost plugins.lua PackerCompile'

return require("packer").startup(
    function(use)
        use 'wbthomason/packer.nvim'

        use "nvim-treesitter/nvim-treesitter"
        use "p00f/nvim-ts-rainbow"

        use "neovim/nvim-lspconfig"
        use "kabouzeid/nvim-lspinstall"
        use "hrsh7th/nvim-compe"
        use "ray-x/lsp_signature.nvim"

        use "dense-analysis/ale" -- TODO: Replace with Lua based plugin
        use "tanvirtin/monokai.nvim"
        use "nvim-lua/popup.nvim"
        use "nvim-lua/plenary.nvim"
        use "nvim-telescope/telescope.nvim"
    end
)
