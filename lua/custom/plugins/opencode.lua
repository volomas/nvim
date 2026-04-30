return {
  'sudo-tee/opencode.nvim',
  config = function()
    require('opencode').setup {}
  end,
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        anti_conceal = { enabled = false },
        file_types = { 'markdown', 'opencode_output' },
      },
      ft = { 'markdown', 'opencode_output' },
    },
    'saghen/blink.cmp',
    'folke/snacks.nvim',
  },
}
-- vim: ts=2 sts=2 sw=2 et
