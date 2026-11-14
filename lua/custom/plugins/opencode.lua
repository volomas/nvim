return {
  'sudo-tee/opencode.nvim',
  config = function()
    require('opencode').setup {}
  end,
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- markdown rendering for opencode output, configured in custom/plugins/render-markdown.lua
    'MeanderingProgrammer/render-markdown.nvim',
    'saghen/blink.cmp',
    'folke/snacks.nvim',
  },
}
-- vim: ts=2 sts=2 sw=2 et
