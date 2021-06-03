local cmd = vim.cmd -- to execute Vim commands e.g. cmd('pwd')
local fn = vim.fn -- to call Vim functions e.g. fn.bufnr()
local g = vim.g -- a table to access global variables))

g.mapleader = ","

cmd "packadd paq-nvim" -- load the package manager
local paq = require("paq-nvim").paq -- a convenient alias
paq {"savq/paq-nvim", opt = true} -- paq-nvim manages itself

paq {"nvim-treesitter/nvim-treesitter"}
paq {"neovim/nvim-lspconfig"}
paq {"kabouzeid/nvim-lspinstall"}
paq {"hrsh7th/nvim-compe"}
paq {"ray-x/lsp_signature.nvim"}
paq {"dense-analysis/ale"} -- TODO: Replace with Lua based plugin
-- paq {'ojroques/nvim-lspfuzzy'}

paq {"tanvirtin/monokai.nvim"}

paq {"nvim-lua/popup.nvim"}
paq {"nvim-lua/plenary.nvim"}
paq {"nvim-telescope/telescope.nvim"}

local scopes = {o = vim.o, b = vim.bo, w = vim.wo}

local function opt(scope, key, value)
    scopes[scope][key] = value
    if scope ~= "o" then
        scopes["o"][key] = value
    end
end

local indent = 4
cmd "silent! colorscheme monokai" -- Put your favorite colorscheme here

opt("b", "expandtab", true) -- Use spaces instead of tabs
opt("b", "shiftwidth", indent) -- Size of an indent
opt("b", "smartindent", true) -- Insert indents automatically
opt("b", "tabstop", indent) -- Number of spaces tabs count for
opt("o", "completeopt", "menuone,noinsert,noselect") -- Completion options (for deoplete)
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

map("n", "<leader>ts", '<cmd>lua require("telescope.builtin").treesitter()<cr>') -- Insert a newline in normal mode

map("n", "<leader>li", '<cmd>lua require("telescope.builtin").lsp_implementations()<cr>') -- Insert a newline in normal mode
map("n", "<leader>ld", '<cmd>lua require("telescope.builtin").lsp_definitions()<cr>') -- Insert a newline in normal mode

map("n", "<A-Up>", "<cmd>:tabnew<cr>") -- Alt + Arrow Up, new tab
map("n", "<A-Left>", "<cmd>:tabprev<cr>") -- Alt + Arrow Left, tab left
map("n", "<A-Right>", "<cmd>:tabnext<cr>") -- Alt + Arrow Right, tab right
map("n", "<tab>", "<c-w>w") -- tab, circular window shifting
map("n", "<S-tab>", "<c-w>W") -- shift tab

g.ale_linters = {
    go = {"golangci-lint"},
    terraform = {"terraform", "tflint"},
    python = {"pylint", "flake8", "pyre", "mypy", "pyright"},
    ansible = {"ansible-lint"},
    dockerfile = {"dockerfile_lint", "hadolint"},
    swift = {"apple-swift-format"},
    fish = {"fish_indent"}
}

g.ale_fixers = {
    javascript = {"prettier", "eslint"},
    typescript = {"prettier", "eslint"},
    elm = {"format"},
    sh = {"shfmt"},
    go = {"goimports"},
    terraform = {"terraform", "terraform-fmt-fixer"},
    html = {"prettier"},
    css = {"prettier"},
    scss = {"prettier"},
    json = {"prettier"},
    yaml = {"prettier"},
    fsharp = {"fantomas"},
    python = {"autoimport", "isort", "black"},
    lua = {"luafmt", "black"},
    swift = {"apple-swift-format"}
}
g.ale_fixers["*"] = {"remove_trailing_lines", "trim_whitespace"}

g.ale_fix_on_save = 1
g.ale_lint_on_save = 1
g.ale_completion_enabled = 0
g.ale_sign_column_always = 1
g.ale_linters_explicit = 0
g.ale_python_flake8_options = "--max-line-length=88"

local ts = require "nvim-treesitter.configs"
ts.setup {ensure_installed = "maintained", highlight = {enable = true}}

local lsp = require "lspconfig"
-- local lspfuzzy = require 'lspfuzzy' -- TODO: Use fuzzer, telescope?

-- lsp.sourcekit.setup {}
-- lsp.dockerls.setup {}
-- lsp.gopls.setup {}
-- lsp.html.setup {}
-- lsp.cssls.setup {}
-- lsp.elmls.setup {}
-- lsp.jsonls.setup {}
-- lsp.terraformls.setup {}
-- lsp.tflint.setup {}
-- lsp.yamlls.setup {}
-- lsp.groovyls.setup {}
-- lsp.pyright.setup {
--     root_dir = lsp.util.root_pattern(".git", fn.getcwd())
-- }
-- lsp.pyls.setup {
--     root_dir = lsp.util.root_pattern(".git", fn.getcwd())
-- }

-- lsp-install
-- Servers available in: 
-- ~/.local/share/nvim/site/pack/paqs/start/nvim-lspinstall/lua/lspinstall/servers.lua
local function setup_servers()
    require "lspinstall".setup()

    -- get all installed servers
    local servers = require "lspinstall".installed_servers()
    -- ... and add manually installed servers
    table.insert(servers, "clangd")
    table.insert(servers, "sourcekit")

    for _, server in pairs(servers) do
        local config = {capabilities = vim.lsp.protocol.make_client_capabilities()}

        -- language specific config
        if server == "sourcekit" then
            config.filetypes = {"swift", "objective-c", "objective-cpp"} -- we don't want c and cpp!
        end
        if server == "clangd" then
            config.filetypes = {"c", "cpp"} -- we don't want objective-c and objective-cpp!
        end

        require "lspconfig"[server].setup(config)
    end
end

setup_servers()

-- Automatically reload after `:LspInstall <server>` so we don't have to restart neovim
require "lspinstall".post_install_hook = function()
    setup_servers() -- reload installed servers
    vim.cmd("bufdo e") -- this triggers the FileType autocmd that starts the server
end

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
opt("o", "completeopt", "menuone,noselect")

require "lsp_signature".on_attach()
