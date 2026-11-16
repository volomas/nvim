-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
--  You can configure plugins using the `config` key.
--
--  You can also configure plugins after the setup call,
--    as they will be available in your neovim runtime.
require('lazy').setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  { 'NMAC427/guess-indent.nvim', opts = {} }, -- Detect tabstop and shiftwidth automatically
  'tpope/vim-fugitive',
  'tpope/vim-rhubarb',
  'tpope/vim-dadbod',
  -- vim-unimpaired removed: [d/]d, [q/]q, [b/]b etc. are now Neovim 0.12 defaults
  'tpope/vim-obsession',
  'unblevable/quick-scope',
  'nvim-tree/nvim-web-devicons',
  -- 'github/copilot.vim',

  -- for markdown preview
  { 'ellisonleao/glow.nvim', config = true, cmd = 'Glow' },
  {
    'yousefhadder/markdown-plus.nvim',
    ft = 'markdown',
    opts = {},
  },
  {
    'blazkowolf/gruber-darker.nvim',
    opts = {
      bold = false,
      italic = {
        strings = false,
      },
    },
  },
  {
    'ellisonleao/gruvbox.nvim',
    lazy = true, -- loaded on :colorscheme
    config = true,
    opts = {
      terminal_colors = true, -- add neovim terminal colors
      undercurl = true,
      underline = true,
      bold = false,
      italic = {
        strings = false,
        emphasis = false,
        comments = false,
        operators = false,
        folds = false,
      },
      strikethrough = true,
      invert_selection = false,
      invert_signs = false,
      invert_tabline = false,
      inverse = true, -- invert background for search, diffs, statuslines and errors
      contrast = 'hard', -- can be "hard", "soft" or empty string
      palette_overrides = {},
      overrides = {},
      dim_inactive = false,
      transparent_mode = false,
    },
  },

  -- themes
  {
    'pmouraguedes/neodarcula.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      -- stock neodarcula background is near-black (#000001); lift it to JetBrains'
      -- New UI dark palette so it is easier on the eyes, and raise the tones that
      -- are derived from it (cursor line, popups, inactive windows) to match.
      local neodarcula = require 'neodarcula'
      neodarcula.colors.bg = '#1E1F22'
      neodarcula.colors.current_line = '#2B2D30'
      neodarcula.colors.bg_inactive = '#2B2D30'
      -- stock fg is near-white (#DDDDDD); use IntelliJ's New UI text colour instead
      neodarcula.colors.fg = '#BCBEC4'
    end,
  },

  {
    'rebelot/kanagawa.nvim',
    lazy = true, -- loaded on :colorscheme
  },

  -- Light themes, installed only to compare them (:LightNext / :LightTheme).
  -- None of them is set as the default; nvim still starts on neodarcula.
  {
    'neanias/everforest-nvim',
    lazy = true, -- loaded on :colorscheme
    config = function()
      -- "soft" = the darkest/least contrasty of the three background weights
      require('everforest').setup { background = 'soft' }
    end,
  },

  {
    'zenbones-theme/zenbones.nvim',
    lazy = true, -- loaded on :colorscheme
    dependencies = { 'rktjmp/lush.nvim' },
  },

  {
    'sainnhe/gruvbox-material',
    lazy = true, -- loaded on :colorscheme
    config = function()
      vim.g.gruvbox_material_background = 'soft'
      vim.g.gruvbox_material_palette = 'material'
      vim.g.gruvbox_material_better_performance = 1
    end,
  },

  {
    'savq/melange-nvim',
    lazy = true, -- loaded on :colorscheme
  },

  {
    'projekt0n/github-nvim-theme',
    lazy = true, -- loaded on :colorscheme
    config = function()
      require('github-theme').setup {
        -- ...
      }
    end,
  },
  { 'rose-pine/neovim', name = 'rose-pine', lazy = true },

  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- See `:help lualine.txt`
    opts = {
      options = {
        icons_enabled = false,
        theme = 'auto',
        component_separators = '|',
        section_separators = '',
      },
      sections = {
        lualine_x = {
          -- One line, all in-flight LSP tasks joined (see lua/lsp-progress.lua)
          function()
            return require('lsp-progress').status()
          end,
          'encoding',
          'fileformat',
          'filetype',
        },
      },
    },
  },

  -- Comment.nvim removed: Neovim has built-in gc/gcc since 0.10

  -- modular approach: using `require 'path/name'` will
  -- include a plugin definition from file lua/path/name.lua

  require 'kickstart.plugins.gitsigns',

  require 'kickstart.plugins.which-key',

  require 'kickstart.plugins.telescope',

  require 'kickstart.plugins.lspconfig',

  require 'kickstart.plugins.conform',

  require 'kickstart.plugins.blink-cmp',

  require 'kickstart.plugins.todo-comments',

  require 'kickstart.plugins.mini',

  require 'kickstart.plugins.treesitter',

  require 'kickstart.plugins.debug',

  require 'kickstart.plugins.lint',

  require 'kickstart.plugins.autopairs',

  -- user plugins: lua/custom/plugins/*.lua
  { import = 'custom.plugins' },
}, {
  git = {
    url_format = 'git@github.com:%s.git', -- use SSH instead of HTTPS
  },
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- vim: ts=2 sts=2 sw=2 et
