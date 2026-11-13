return {
  'kristijanhusak/vim-dadbod-ui',
  dependencies = {
    { 'tpope/vim-dadbod', lazy = true },
    {
      'kristijanhusak/vim-dadbod-completion',
      ft = { 'sql', 'mysql', 'plsql' },
      lazy = true,
    },
  },
  cmd = {
    'DBUI',
    'DBUIToggle',
    'DBUIAddConnection',
    'DBUIFindBuffer',
    -- vim-dadbod itself: run a query from any buffer, e.g.
    --   :DB postgresql://user@host:5432/dbname
    'DB',
  },
  init = function()
    -- Your DBUI configuration
    vim.g.db_ui_use_nerd_fonts = 1

    -- Drawer default query. Upstream default uses `LIMIT`, which T-SQL (Fabric) rejects.
    vim.g.db_ui_default_query = 'SELECT TOP 100 * FROM "{table}";'

    -- Let blink.cmp own SQL completion; keep the builtin omni out of the way.
    vim.g.omni_sql_default_compl_type = 'syntax'
    vim.g.loaded_sql_completion = true
  end,
}
-- vim: ts=2 sts=2 sw=2 et
