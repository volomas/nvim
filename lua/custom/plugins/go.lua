return {
  'ray-x/go.nvim',
  dependencies = { -- optional packages
    'ray-x/guihua.lua',
    'neovim/nvim-lspconfig',
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('go').setup {
      lsp_cfg = false, -- mason-lspconfig handles gopls
      lsp_keymaps = false, -- use global LSP keymaps
      lsp_codelens = true, -- enable code lens
      lsp_inlay_hints = { enable = false }, -- handled globally
      diagnostic = false, -- use global diagnostic config
      trouble = true, -- integrate with trouble.nvim
      test_runner = 'go', -- use 'go test' command
      run_in_floaterm = true, -- run commands in floating terminal
      floaterm = {
        position = 'center',
        width = 0.8,
        height = 0.8,
      },
    }
  end,
  event = { 'CmdlineEnter' },
  ft = { 'go', 'gomod' },
  build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
}
