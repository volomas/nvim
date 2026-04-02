local M = {}

M.organize_imports = function()
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  vim.lsp.buf.code_action {
    context = {
      diagnostics = vim.diagnostic.get(0, { lnum = lnum }),
      only = { 'source.organizeImports' },
    },
    apply = true,
  }
end

return M
