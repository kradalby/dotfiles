vim.g.mapleader = " "

require("nix")
require("config.options")
require("config.filetype")
require("config.completion")
require("config.format")
require("config.lint")
require("config.todo")
require("config.lsp")
require("config.telescope")
require("config.plugins")

local keymap = vim.keymap

-- Editing
keymap.set("n", "<leader>o", "m`o<Esc>``", { desc = "Insert blank line below" })

-- Window navigation
keymap.set("n", "<tab>", "<c-w>w", { desc = "Next window" })
keymap.set("n", "<S-tab>", "<c-w>W", { desc = "Prev window" })

-- Tabs
keymap.set("n", "<A-Up>", "<cmd>tabnew<cr>", { desc = "New tab" })
keymap.set("n", "<A-Left>", "<cmd>tabprev<cr>", { desc = "Prev tab" })
keymap.set("n", "<A-Right>", "<cmd>tabnext<cr>", { desc = "Next tab" })

-- Clipboard (macOS GUI)
keymap.set("i", "<D-c>", '<Esc>"+yi', { desc = "Copy (macOS)" })
keymap.set("i", "<D-v>", '<Esc>"+pi', { desc = "Paste (macOS)" })
