-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', 'ge', vim.diagnostic.goto_next, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', 'gE', vim.diagnostic.goto_prev, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>E', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>dl', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

vim.keymap.set('n', '\\\\', ':noh<CR>', { noremap = true })
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')
vim.keymap.set('n', '<C-f>', '<cmd>silent !tmux neww tmux-sessionizer.sh<CR>')
vim.keymap.set('n', '==', vim.lsp.buf.format)
vim.keymap.set('x', '<leader>p', [["_dP]])
vim.keymap.set('n', '<leader>1', '1gt')
vim.keymap.set('n', '<leader>2', '2gt')
vim.keymap.set('n', '<leader>3', '3gt')
vim.keymap.set('n', '<leader>4', '4gt')
vim.keymap.set('n', '<leader>5', '5gt')
vim.keymap.set('n', '<C-q>', ':qall<CR>')
-- alternate file mapping on backspace
vim.keymap.set('n', '<BS>', '<C-^>')

-- repeatble indent in visual mode
vim.keymap.set('x', '>', [[>gv]])
vim.keymap.set('x', '<', [[<gv]])

-- copilot
vim.keymap.set('i', '<C-j>', 'copilot#Next()', { expr = true, silent = true })
vim.keymap.set('i', '<C-k>', 'copilot#Previous()', { expr = true, silent = true })

-- Toogle file explorer
-- vim.keymap.set("n", "<leader>e", "<cmd>Lexplore<CR>")
-- vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
-- vim.api.nvim_set_keymap("n", "<leader>e", ":NvimTreeToggle<cr>", {silent = true, noremap = true})
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeFindFile<cr>', { silent = true, noremap = true })

-- Freed <C-l> in Netrw
-- https://github.com/christoomey/vim-tmux-navigator/issues/189
-- When in netrw, c-l is refreshing the file tree, but c-l is bind in neovim to move to the left pane
-- The trick here is bind it some rnadom combo
vim.keymap.set('n', '<leader><leader><leader><leader><leader><leader>l', '<Plug>NetrwRefresh')

local api = require 'Comment.api'

vim.keymap.set('n', '<C-_>', api.toggle.linewise.current)
vim.keymap.set('x', '<C-_>', '<Plug>(comment_toggle_linewise_visual)')

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

-- vim: ts=2 sts=2 sw=2 et
