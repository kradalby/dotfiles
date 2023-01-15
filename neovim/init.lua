require("nix")
require("statusline")
require("completion")
require("todo")
require("lsp")
require("debug")

local cmd = vim.cmd -- to execute Vim commands e.g. cmd('pwd')
local fn = vim.fn -- to call Vim functions e.g. fn.bufnr()
local g = vim.g -- a table to access global variables))
local opt = vim.opt
local keymap = vim.keymap

g.mapleader = " "

opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevel = 20

local indent = 4
cmd "silent! colorscheme tokyonight"
cmd "set signcolumn=yes"

g.tokyonight_style = "night"
g.tokyonight_transparent = true

opt.expandtab = true -- Use spaces instead of tabs
opt.shiftwidth = indent -- Size of an indent
opt.smartindent = true -- Insert indents automatically
opt.tabstop = indent -- Number of spaces tabs count for
opt.completeopt = { "menu", "menuone", "noinsert", "noselect" }
-- opt.completeopt = {"menuone", "noinsert", "noselect"}
opt.hidden = true -- Enable modified buffers in background
opt.ignorecase = true -- Ignore case
opt.joinspaces = false -- No double spaces with join after a dot
opt.scrolloff = 4 -- Lines of context
opt.shiftround = true -- Round indent
opt.sidescrolloff = 8 -- Columns of context
opt.smartcase = true -- Don't ignore case with capitals
opt.splitbelow = true -- Put new windows below current
opt.splitright = true -- Put new windows right of current
opt.termguicolors = true -- True color support
opt.wildmode = { "list", "longest" } -- Command-line completion mode
opt.list = true -- Show some invisible characters (tabs...
opt.listchars = { tab = ">·", trail = "·", extends = ">", precedes = "<" } -- Show some invisible characters (tabs...
opt.number = true -- Print line number
opt.relativenumber = false -- Relative line numbers
opt.wrap = true -- Disable line wrap

keymap.set("n", "<leader>o", "m`o<Esc>``", {}) -- Insert a newline in normal mode

keymap.set('n', '<leader>ff', vim.lsp.buf.format, {})

keymap.set("n", "<leader>tt", "<cmd>:TroubleToggle<cr>", {}) -- Toggle trouble
keymap.set("n", "<leader>to", "<cmd>:TodoTrouble<cr>", {}) -- Toggle trouble

keymap.set("n", "<leader>h", "<cmd>:Lspsaga hover_doc<cr>", {})
keymap.set("n", "<leader>r", "<cmd>:Lspsaga rename<cr>", {})
keymap.set("n", "<leader>a", "<cmd>:Lspsaga code_action<cr>", {})
-- keymap.set("n", "<leader>d", "<cmd>:Lspsaga preview_definition<cr>", {})
keymap.set("n", "<leader>dn", "<cmd>:Lspsaga diagnostic_jump_next<cr>", {})
keymap.set("n", "<leader>dp", "<cmd>:Lspsaga diagnostic_jump_prev<cr>", {})

keymap.set("n", "<A-Up>", "<cmd>:tabnew<cr>", {}) -- Alt + Arrow Up, new tab
keymap.set("n", "<A-Left>", "<cmd>:tabprev<cr>", {}) -- Alt + Arrow Left, tab left
keymap.set("n", "<A-Right>", "<cmd>:tabnext<cr>", {}) -- Alt + Arrow Right, tab right
keymap.set("n", "<tab>", "<c-w>w", {}) -- tab, circular window shifting
keymap.set("n", "<S-tab>", "<c-w>W", {}) -- shift tab

keymap.set("i", "<D-c>", '<Esc>"+yi', {})
keymap.set("i", "<D-v>", '<Esc>"+pi', {})

require("tele")
require("plugins")
