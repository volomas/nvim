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
    -- IntelliJ-style review entry points
    { '<leader>vR', '<cmd>DiffviewOpen HEAD~1..HEAD<cr>', desc = '[V]cs: [R]eview last commit' },
    { '<leader>vS', '<cmd>DiffviewOpen --staged<cr>', desc = '[V]cs: review [S]taged changes' },
    { '<leader>vW', '<cmd>DiffviewOpen HEAD<cr>', desc = '[V]cs: review [W]orking tree changes' },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      -- Side-by-side (left | right) layout, like IntelliJ's diff viewer
      default = { layout = 'diff2_horizontal' },
      file_history = { layout = 'diff2_horizontal' },
    },
    hooks = {
      -- Cleaner buffers while reviewing
      diff_buf_read = function(bufnr)
        vim.opt_local.wrap = false
        vim.opt_local.list = false
        vim.opt_local.colorcolumn = {}
        vim.opt_local.spell = false
      end,
    },
  },
  config = function(_, opts)
    -- Diagonal fill for deleted lines (the IntelliJ diff look)
    vim.opt.fillchars:append { diff = '╱' }

    local actions = require('diffview.actions')

    opts.keymaps = {
      view = {
        -- Next/prev file: IntelliJ F7-style plus vim-style
        { 'n', '<F7>', actions.select_next_entry, { desc = 'Open the diff for the next file' } },
        { 'n', '<S-F7>', actions.select_prev_entry, { desc = 'Open the diff for the previous file' } },
        { 'n', ']f', actions.select_next_entry, { desc = 'Open the diff for the next file' } },
        { 'n', '[f', actions.select_prev_entry, { desc = 'Open the diff for the previous file' } },
        { 'n', '<esc>', actions.close, { desc = 'Close the diff view' } },
      },
    }

    require('diffview').setup(opts)
  end,
}
-- vim: ts=2 sts=2 sw=2 et
