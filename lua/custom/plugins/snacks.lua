return {
  -- Only the modules configured here get enabled, so this spec stays light.
  -- input = prettier `vim.ui.input`, used by LSP rename and other prompts.
  'folke/snacks.nvim',
  lazy = false,
  priority = 1000,
  opts = {
    input = { enabled = true },
  },
}
-- vim: ts=2 sts=2 sw=2 et
