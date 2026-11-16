return {
  { -- Collection of various small independent plugins/modules
    'nvim-mini/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yiNq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup {
        -- NOTE: `an`/`in` clash with Neovim 0.12's built-in incremental selection (visual mode),
        -- and `aa`/`ia` are used by the treesitter parameter textobjects.
        mappings = {
          around_next = 'aN',
          inside_next = 'iN',
        },
        n_lines = 500,
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()
      -- Statusline is lualine (lazy-plugins.lua); mini.statusline was competing with it.
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
