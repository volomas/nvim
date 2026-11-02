-- Theme switching.
--
-- Defaults are untouched: nvim still starts on `neodarcula` (:Dark) and :Light
-- still means gruvbox light. The extra light schemes are installed only so they
-- can be compared side by side:
--
--   :LightNext          cycle through every light theme
--   :LightTheme <name>  jump straight to one (tab-completed)
--   :LightTheme         list them
local M = {}

-- Order used by :LightNext. `gruvbox` is the existing light theme, kept last as
-- the reference point.
M.light_themes = {
  { name = 'kanagawa-lotus', label = 'Kanagawa Lotus' },
  { name = 'everforest', label = 'Everforest Light (soft)' },
  { name = 'neobones', label = 'Neobones (light)' },
  { name = 'zenbones', label = 'Zenbones (light)' },
  { name = 'gruvbox-material', label = 'Gruvbox Material (light, soft)' },
  { name = 'melange', label = 'Melange (light)' },
  { name = 'gruvbox', label = 'Gruvbox (light, current default)' },
}

-- Setting 'background' while a colorscheme is active makes Neovim re-source that
-- (old) scheme, which fires a stale ColorScheme event. Clear colors_name first,
-- and reset highlights ourselves since some schemes only do that when colors_name is set.
function M.apply(scheme, background)
  vim.g.colors_name = nil
  vim.cmd.highlight 'clear'
  vim.o.background = background -- gruvbox/kanagawa/melange pick their variant from 'background'
  vim.cmd.colorscheme(scheme)
end

function M.dark()
  M.apply('neodarcula', 'dark')
end

function M.light(scheme)
  M.apply(scheme or 'gruvbox', 'light')
end

local index = 1

function M.next()
  local theme = M.light_themes[index]
  M.apply(theme.name, 'light')
  vim.notify(('Light theme %d/%d: %s'):format(index, #M.light_themes, theme.label), vim.log.levels.INFO)
  index = index % #M.light_themes + 1
end

local function complete(arg_lead)
  local matches = {}
  for _, theme in ipairs(M.light_themes) do
    if vim.startswith(theme.name, arg_lead) then
      table.insert(matches, theme.name)
    end
  end
  return matches
end

function M.setup()
  vim.api.nvim_create_user_command('Dark', M.dark, { desc = 'Dark theme (neodarcula)' })
  vim.api.nvim_create_user_command('Light', function()
    M.light()
  end, { desc = 'Default light theme (gruvbox)' })
  vim.api.nvim_create_user_command('LightNext', M.next, { desc = 'Cycle through the installed light themes' })
  vim.api.nvim_create_user_command('LightTheme', function(opts)
    if opts.args == '' then
      local lines = {}
      for i, theme in ipairs(M.light_themes) do
        table.insert(lines, ('%d. %-18s %s'):format(i, theme.name, theme.label))
      end
      vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
      return
    end
    M.apply(opts.args, 'light')
  end, { nargs = '?', complete = complete, desc = 'Apply an installed light theme' })
end

return M

-- vim: ts=2 sts=2 sw=2 et
