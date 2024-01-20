return {
  "ThePrimeagen/refactoring.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    local refac = require("refactoring")
    refac.setup({
      -- prompt for return type
      prompt_func_return_type = {
        go = true,
        cpp = true,
        c = true,
        java = true,
      },
      -- prompt for function parameters
      prompt_func_param_type = {
        go = true,
        cpp = true,
        c = true,
        java = true,
      },
    })
    require("telescope").load_extension("refactoring")

    -- Extract function supports only visual mode
    vim.keymap.set("x", "<leader>rv", function() require('refactoring').refactor('Extract Variable') end)
    vim.keymap.set(
      { "n", "x" },
      "<leader>rr",
      function() require('telescope').extensions.refactoring.refactors() end
    )
  end,
}
