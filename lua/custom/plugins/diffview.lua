return {
  'sindrets/diffview.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  cmd = {
    'DiffviewOpen',
    'DiffviewClose',
    'DiffviewFileHistory',
    'DiffviewToggleFiles',
    'DiffviewFocusFiles',
    'DiffviewRefresh',
  },
  keys = {
    { '<leader>vo', '<cmd>DiffviewOpen<cr>', desc = '[V]cs: [O]pen diff view' },
    { '<leader>vc', '<cmd>DiffviewClose<cr>', desc = '[V]cs: [C]lose diff view' },
    { '<leader>vf', '<cmd>DiffviewFileHistory %<cr>', desc = '[V]cs: [F]ile history (current file)' },
    { '<leader>vF', '<cmd>DiffviewFileHistory<cr>', desc = '[V]cs: [F]ile history (repository)' },
  },
  opts = {
    enhanced_diff_hl = true,
  },
}
-- vim: ts=2 sts=2 sw=2 et
