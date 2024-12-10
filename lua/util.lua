local M = {}

M.organize_imports = function()
  vim.lsp.buf.code_action {
    context = {
      diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
      only = { 'source.organizeImports' },
    },
    apply = true,
  }
end

return M
