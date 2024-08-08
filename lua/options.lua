-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--
-- netrw settings
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 30
vim.g.netrw_browse_split = 0
vim.g.netrw_preview = 1
vim.g.netrw_altv = 1
vim.g.netrw_liststyle = 3

vim.g.editorconfig = true

-- Set highlight on search
vim.o.hlsearch = true
vim.o.incsearch = true


-- Make line numbers default
vim.wo.number = true
-- vim.o.nu = true
vim.o.relativenumber = true
vim.opt.scrolloff = 8
vim.opt.colorcolumn = "100"

vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smarttab = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 100

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- vim: ts=2 sts=2 sw=2 et
