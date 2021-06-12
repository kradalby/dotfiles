require("plugins")
require("statusline")
require("ale")

local cmd = vim.cmd -- to execute Vim commands e.g. cmd('pwd')
local fn = vim.fn -- to call Vim functions e.g. fn.bufnr()
local g = vim.g -- a table to access global variables))

g.mapleader = ","

cmd "set guifont=Jetbrains\\ Mono:h11" -- Set neovide font

local scopes = {o = vim.o, b = vim.bo, w = vim.wo}

local function opt(scope, key, value)
    scopes[scope][key] = value
    if scope ~= "o" then
        scopes["o"][key] = value
    end
end

local indent = 4
cmd "silent! colorscheme monokai" -- Put your favorite colorscheme here
cmd "set signcolumn=yes" -- Put your favorite colorscheme here

opt("b", "expandtab", true) -- Use spaces instead of tabs
opt("b", "shiftwidth", indent) -- Size of an indent
opt("b", "smartindent", true) -- Insert indents automatically
opt("b", "tabstop", indent) -- Number of spaces tabs count for
opt("o", "completeopt", "menuone,noselect")
opt("o", "hidden", true) -- Enable modified buffers in background
opt("o", "ignorecase", true) -- Ignore case
opt("o", "joinspaces", false) -- No double spaces with join after a dot
opt("o", "scrolloff", 4) -- Lines of context
opt("o", "shiftround", true) -- Round indent
opt("o", "sidescrolloff", 8) -- Columns of context
opt("o", "smartcase", true) -- Don't ignore case with capitals
opt("o", "splitbelow", true) -- Put new windows below current
opt("o", "splitright", true) -- Put new windows right of current
opt("o", "termguicolors", true) -- True color support
opt("o", "wildmode", "list:longest") -- Command-line completion mode
opt("w", "list", true) -- Show some invisible characters (tabs...)
opt("w", "listchars", "tab:>·,trail:·,extends:>,precedes:<") -- Show some invisible characters (tabs...)
opt("w", "number", true) -- Print line number
opt("w", "relativenumber", true) -- Relative line numbers
opt("w", "wrap", true) -- Disable line wrap

local function map(mode, lhs, rhs, opts)
    local options = {noremap = true}
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map("n", "<leader>o", "m`o<Esc>``") -- Insert a newline in normal mode

map("n", "<leader>ff", '<cmd>lua require("telescope.builtin").find_files()<cr>') -- Insert a newline in normal mode
map("n", "<leader>fg", '<cmd>lua require("telescope.builtin").live_grep()<cr>') -- Insert a newline in normal mode
map("n", "<leader>fb", '<cmd>lua require("telescope.builtin").file_browser()<cr>') -- Insert a newline in normal mode
map("n", "<leader>ft", '<cmd>lua require("telescope.builtin").filetypes()<cr>') -- Insert a newline in normal mode

map("n", "<leader>tt", "<cmd>:TroubleToggle<cr>") -- Toggle trouble

map("n", "<leader>ts", '<cmd>lua require("telescope.builtin").treesitter()<cr>') -- Insert a newline in normal mode

map("n", "<leader>li", '<cmd>lua require("telescope.builtin").lsp_implementations()<cr>') -- Insert a newline in normal mode
map("n", "<leader>ld", '<cmd>lua require("telescope.builtin").lsp_definitions()<cr>') -- Insert a newline in normal mode

map("n", "<A-Up>", "<cmd>:tabnew<cr>") -- Alt + Arrow Up, new tab
map("n", "<A-Left>", "<cmd>:tabprev<cr>") -- Alt + Arrow Left, tab left
map("n", "<A-Right>", "<cmd>:tabnext<cr>") -- Alt + Arrow Right, tab right
map("n", "<tab>", "<c-w>w") -- tab, circular window shifting
map("n", "<S-tab>", "<c-w>W") -- shift tab

-- Ensure plugins are installed before we load LSP
if #vim.fn.readdir(fn.stdpath("data") .. "/site/pack/packer/start") > 1 then
    require("lsp")
end
