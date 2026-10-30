--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Detect zsh C-x C-e temp files as bash so LSP/completion works
vim.filetype.add {
  pattern = {
    ['.*/tmp/zsh.*'] = 'bash',
    ['.*/tmp/bash%-fc.*'] = 'bash',
  },
}

-- folding
vim.api.nvim_create_autocmd({ 'FileType' }, {
  callback = function()
    vim.wo.foldlevel = 99
    local language = vim.treesitter.language.get_lang(vim.bo.filetype)
    if language and vim.treesitter.language.add(language) then
      vim.wo.foldmethod = 'expr'
      vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    else
      vim.wo.foldmethod = 'syntax'
    end
  end,
})

-- to make sign bar and numbers bar bg transparent
local side = vim.api.nvim_create_augroup('transparentBg', { clear = true })
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    -- match Normal's bg instead of NONE so the terminal bg never bleeds through when switching themes
    local bg = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg
    for _, group in ipairs { 'SignColumn', 'LineNr', 'GitSignsAdd', 'GitSignsChange', 'GitSignsDelete' } do
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      hl.bg = bg
      vim.api.nvim_set_hl(0, group, hl)
    end
  end,
  group = side,
  pattern = '*',
})

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
require 'options'

-- [[ Install `lazy.nvim` plugin manager ]]
require 'lazy-bootstrap'

-- [[ Configure and install plugins ]]
require 'lazy-plugins'

-- [[ Basic Keymaps ]]
require 'keymaps'

-- Setting 'background' while a colorscheme is active makes Neovim re-source that
-- (old) scheme, which fires a stale ColorScheme event. Clear colors_name first,
-- and reset highlights ourselves since some schemes only do that when colors_name is set.
local function apply_theme(scheme, background)
  vim.g.colors_name = nil
  vim.cmd.highlight 'clear'
  vim.o.background = background -- gruvbox picks its variant from 'background'
  vim.cmd.colorscheme(scheme)
end

local lightFunc = function()
  apply_theme('github_light', 'light')
end

local darkFunc = function()
  apply_theme('neodarcula', 'dark')
end

-- custom commands to switch between Light/Dark themes
vim.api.nvim_create_user_command('Light', lightFunc, {})
vim.api.nvim_create_user_command('Dark', darkFunc, {})

-- dark theme by default
vim.cmd [[Dark]]

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
