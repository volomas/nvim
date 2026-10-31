-- Thin line instead of a full-cell colorcolumn block. Reads 'colorcolumn' from options.lua.
return {
  'lukas-reineke/virt-column.nvim',
  event = 'BufReadPost',
  opts = {
    char = '▏',
    highlight = 'VirtColumn',
  },
}
-- vim: ts=2 sts=2 sw=2 et
