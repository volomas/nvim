return {
  'karb94/neoscroll.nvim',
  config = function()
    require('neoscroll').setup {
      mappings = { '<C-u>', '<C-d>', '<C-b>', '<C-f>', '<C-e>', '<C-y>' },
    }
  end,
}
