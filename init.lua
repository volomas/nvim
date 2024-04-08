-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- to make sign bar and numbers bar bg transparent
local side = vim.api.nvim_create_augroup('transparentBg', { clear = true })
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    vim.cmd [[highlight SignColumn guibg=NONE]]
    vim.cmd [[highlight GitSignsAdd guibg=NONE]]
    vim.cmd [[highlight GitSignsChange guibg=NONE]]
    vim.cmd [[highlight GitSignsDelete guibg=NONE]]
    vim.cmd [[highlight LineNr guibg=NONE]]
  end,
  group = side,
  pattern = '*',
})

-- folding
vim.api.nvim_create_autocmd({ "FileType" }, {
  callback = function()
    if require("nvim-treesitter.parsers").has_parser() then
      vim.opt.foldmethod = "expr"
      vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
      vim.opt.foldlevel = 99
    else
      vim.opt.foldmethod = "syntax"
    end
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
require('lazy-bootstrap')

--[[ Configure plugins ]]
require('lazy-plugins')

-- [[ Setting options ]]
require('options')

-- [[ Basic Keymaps ]]
require('keymaps')

-- [[ Configure Telescope ]]
-- (fuzzy finder)
require('telescope-setup')

-- [[ Configure Treesitter ]]
-- (syntax parser for highlighting)
require('treesitter-setup')

-- [[ Configure LSP ]]
-- (Language Server Protocol)
require('lsp-setup')

-- [[ Configure nvim-cmp ]]
-- (completion)
require('cmp-setup')

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
