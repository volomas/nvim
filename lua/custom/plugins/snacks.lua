return {
  -- Only the modules configured here get enabled, so this spec stays light.
  -- input = prettier `vim.ui.input`, used by LSP rename and other prompts.
  'folke/snacks.nvim',
  lazy = false,
  priority = 1000,
  opts = {
    input = {
      enabled = true,
      win = {
        -- Show the prompt next to the cursor, not pinned to the top of the editor.
        -- The built-in "input" style uses relative = "editor", row = 2.
        relative = 'cursor',
        row = -2, -- two lines above the cursor line
        col = 0,
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
