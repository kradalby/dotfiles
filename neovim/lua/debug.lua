local km = vim.keymap
local dap = require("dap")
local dapui = require("dapui")
local tse = require('telescope').extensions

dapui.setup()
require("dap-go").setup()
require("nvim-dap-virtual-text").setup()


km.set("n", "<leader>dc", dap.continue, {silent = true, noremap = true})
km.set("n", "<leader>ds", dap.step_over, {silent = true, noremap = true})
km.set("n", "<leader>dsi", dap.step_into, {silent = true, noremap = true})
km.set("n", "<leader>dso", dap.step_out, {silent = true, noremap = true})
km.set("n", "<leader>db", dap.toggle_breakpoint, {silent = true, noremap = true})
km.set("n", "<leader>dui", dapui.toggle, {silent = true, noremap = true})
km.set("n", "<leader>dro", dap.repl.open, {silent = true, noremap = true})
km.set("n", "<leader>dcc", tse.dap.commands, {silent = true, noremap = true})
km.set("n", "<leader>dlb", tse.dap.list_breakpoints, {silent = true, noremap = true})
km.set("n", "<leader>dv", tse.dap.variables, {silent = true, noremap = true})
km.set("n", "<leader>df", tse.dap.frames, {silent = true, noremap = true})
