local telescope = require("telescope")

telescope.load_extension("fzf")
telescope.load_extension("githubcoauthors")

require("neoclip").setup({
  enable_persistent_history = true,
})

local b = require("telescope.builtin")
local e = require("telescope").extensions

vim.keymap.set("n", "<leader><leader>", b.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", b.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", b.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", b.help_tags, { desc = "Help tags" })
vim.keymap.set("n", "<leader>ft", b.filetypes, { desc = "Filetypes" })
vim.keymap.set("n", "<leader>fk", b.keymaps, { desc = "Keymaps" })
vim.keymap.set("n", "<leader>p", e.neoclip.default, { desc = "Clipboard history" })
vim.keymap.set("n", "<leader>ts", b.treesitter, { desc = "Treesitter symbols" })

-- Co-author insertion for git commits
vim.keymap.set("n", "<leader>gc", "<cmd>Coauth<cr>", { desc = "Insert co-author" })
vim.api.nvim_create_user_command("Coauth", telescope.extensions.githubcoauthors.coauthors, {
  desc = "Insert Co-authored-by lines from git authors",
})
