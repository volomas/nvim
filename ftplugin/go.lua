-- Go-specific buffer settings and keymaps
local map = vim.keymap.set
local opts = { buffer = true }

-- Enable inlay hints by default for Go files (parameter names, type hints)
vim.lsp.inlay_hint.enable(true, { bufnr = 0 })

-- Test keymaps
map('n', '\\r', function()
  require('neotest').run.run()
end, vim.tbl_extend('force', opts, { desc = 'Run nearest test' }))

map('n', '\\u', function()
  require('neotest').run.run_last()
end, vim.tbl_extend('force', opts, { desc = 'Re-run last test' }))

-- Code generation keymaps (via go.nvim)
map('n', '<leader>gi', '<cmd>GoImpl<cr>', vim.tbl_extend('force', opts, { desc = 'Go: Implement interface' }))
map('n', '<leader>ge', '<cmd>GoIfErr<cr>', vim.tbl_extend('force', opts, { desc = 'Go: Generate if err' }))
map('n', '<leader>gfs', '<cmd>GoFillStruct<cr>', vim.tbl_extend('force', opts, { desc = 'Go: Fill struct' }))
map('n', '<leader>gat', '<cmd>GoAddTest<cr>', vim.tbl_extend('force', opts, { desc = 'Go: Generate test' }))
map('n', '<leader>gt', '<cmd>GoAddTag<cr>', vim.tbl_extend('force', opts, { desc = 'Go: Add struct tags' }))
map('n', '<leader>grt', '<cmd>GoRmTag<cr>', vim.tbl_extend('force', opts, { desc = 'Go: Remove struct tags' }))

-- vim: ts=2 sts=2 sw=2 et
