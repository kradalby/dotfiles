local opt = vim.opt

-- Appearance
require("tokyonight").setup({
  style = "night",
  transparent = true,
})
pcall(vim.cmd.colorscheme, "tokyonight")

opt.signcolumn = "yes"
opt.number = true
opt.relativenumber = false
opt.colorcolumn = "80"
opt.wrap = true
opt.cursorline = true
opt.list = true
opt.listchars = { tab = ">·", trail = "·", extends = ">", precedes = "<" }

-- Indentation
local indent = 4
opt.expandtab = true
opt.shiftwidth = indent
opt.tabstop = indent
opt.shiftround = true
opt.breakindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"

-- Behavior
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.splitbelow = true
opt.splitright = true
opt.wildmode = { "list", "longest" }
opt.undofile = true
opt.updatetime = 250

-- Folding (treesitter-based)
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 20
