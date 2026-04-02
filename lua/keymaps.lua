-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
-- Note: [d and ]d are now default mappings in Neovim 0.12
vim.keymap.set('n', 'ge', function() vim.diagnostic.jump { count = 1 } end, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', 'gE', function() vim.diagnostic.jump { count = -1 } end, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', '<leader>E', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>dl', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

vim.keymap.set('n', '\\\\', ':noh<CR>', { noremap = true })
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')
vim.keymap.set('n', '<C-f>', '<cmd>silent !tmux neww tmux-sessionizer<CR>')
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
vim.keymap.set('i', '<C-l>', 'copilot#Previous()', { expr = true, silent = true })

-- Toggle file explorer
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeFindFile<cr>', { silent = true, noremap = true })

-- Comment toggle (using built-in gc/gcc from Neovim 0.10+)
vim.keymap.set('n', '<C-_>', 'gcc', { remap = true, desc = 'Toggle comment' })
vim.keymap.set('x', '<C-_>', 'gc', { remap = true, desc = 'Toggle comment' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})


-- vim: ts=2 sts=2 sw=2 et
