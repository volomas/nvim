return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      -- Go adapter
      'fredrikaverpil/neotest-golang',
    },
    keys = {
      {
        '<leader>ts',
        function()
          require('neotest').summary.toggle()
        end,
        desc = 'Toggle test summary',
      },
      {
        '<leader>to',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = 'Toggle test output panel',
      },
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require 'neotest-golang' {
            go_test_args = { '-v', '-race', '-count=1' },
            dap_go_enabled = true, -- Enable DAP integration for debugging tests
          },
          require 'neotest-java' {
            incremental_build = true,
          },
        },
      }
    end,
  },

  {
    -- Java adapter (JUnit 5). Drives the jdtls client configured in
    -- ftplugin/java.lua. Lazy-loaded on Java buffers and on the :NeotestJava
    -- command, so run `:NeotestJava setup` once to download the JUnit console jar.
    'rcasia/neotest-java',
    ft = 'java',
    cmd = { 'NeotestJava' },
    dependencies = { 'mfussenegger/nvim-jdtls' },
  },
}
-- vim: ts=2 sts=2 sw=2 et
