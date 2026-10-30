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
    -- IntelliJ-style diff: blank fillers instead of the diagonal fill, and muted
    -- inserted/deleted/changed tints (bg only, so syntax colours stay readable).
    vim.opt.fillchars:append { diff = ' ' }

    local function set_diff_hl()
      if vim.o.background ~= 'dark' then
        return
      end
      local groups = {
        DiffAdd = { bg = '#2F4436' }, -- inserted lines (soft green)
        DiffChange = { bg = '#283848' }, -- modified lines (blue-grey)
        DiffDelete = { bg = '#412628' }, -- deleted lines (soft red)
        DiffText = { bg = '#324F6C' }, -- modified characters (brighter blue)
        DiffviewDiffAddAsDelete = { bg = '#412628' }, -- file panel: "added as deleted"
      }
      for group, attrs in pairs(groups) do
        vim.api.nvim_set_hl(0, group, attrs)
      end
    end

    vim.api.nvim_create_autocmd('ColorScheme', {
      group = vim.api.nvim_create_augroup('diffviewDiffHl', { clear = true }),
      callback = set_diff_hl,
    })
    set_diff_hl()

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
