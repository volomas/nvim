return {
  "ThePrimeagen/refactoring.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "lewis6991/async.nvim",
  },
  config = function()
    -- Neovim 0.12: refactoring.nvim needs async.nvim. promise-async (nvim-ufo)
    -- also provides a module named `async`, so point refactoring at vim.async
    -- and let nvim-ufo keep its own `async`.
    local ok, async = pcall(require, "async")
    if ok and async.wrap then
      vim.async = async
      package.loaded["async"] = nil
    end
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
    -- Extract function supports only visual mode
    vim.keymap.set("x", "<leader>rv", function() return require('refactoring').extract_var() end, { expr = true })
    vim.keymap.set(
      { "n", "x" },
      "<leader>rr",
      function() require('refactoring').select_refactor() end
    )
  end,
}
