-- kulala.nvim: JetBrains-compatible HTTP client for .http/.rest files.
-- The same .http files work interchangeably with IntelliJ's HTTP Client
-- (http-client.env.json env files, {{var}} variables, response refs, JS scripts).
--
-- Pinned to the last pre-kulala-core snapshot (upstream v5.3.4, 6656c9d): pure
-- Lua + curl, MIT, no closed-source backend and no license token. Upstream moved
-- the engine into a proprietary `kulala-core` binary in 2026; that is why the
-- pin exists. Patches live on `local/nvim-0.12` of the fork (currently: curl
-- parser no longer drops arguments containing "curl").
-- For local development, swap the repo+branch below for:
--   dir = vim.fn.expand '~/personal/kulala.nvim',
-- Requirements: Neovim 0.10+, curl (grpcurl/websocat/openssl for gRPC/WS/OAuth).
return {
  'volomas/kulala.nvim',
  branch = 'local/nvim-0.12',
  ft = { 'http', 'rest' },
  keys = {
    -- Truthy-only specs: lazy replays the keypress after loading the plugin,
    -- which then maps <leader>R* (see lua/kulala/config/keymaps.lua).
    { '<leader>Rb', desc = 'Open HTTP scratchpad' },
    { '<leader>Ro', desc = 'Open kulala' },
  },
  opts = {
    -- v5 option schema: no kulala_core, no treesitter block (the bundled
    -- kulala_http parser is built through nvim-treesitter automatically).
    -- true = map the default <leader>R* set (send, send all, env, toggle view...);
    -- false would leave .http buffers with no request keymaps at all.
    global_keymaps = true,
    global_keymaps_prefix = '<leader>R',
    kulala_keymaps_prefix = '',
  },
  config = function(_, opts)
    require('kulala').setup(opts)

    -- ideavim-style run keys, .http/.rest buffers only: \ goes with the
    -- existing Run/Debug prefix (\b, \u, \f, \t from nvim-dap).
    local function attach(buf)
      vim.keymap.set({ 'n', 'v' }, '\\r', function()
        require('kulala').run()
      end, {
        buffer = buf,
        desc = 'Kulala: run request under cursor',
      })
      vim.keymap.set('n', '\\e', function()
        require('kulala').set_selected_env()
      end, {
        buffer = buf,
        desc = 'Kulala: select environment',
      })
      vim.keymap.set('n', '\\y', function()
        require('kulala').copy()
      end, {
        buffer = buf,
        desc = 'Kulala: copy request as cURL',
      })
      vim.keymap.set('n', '\\p', function()
        require('kulala').from_curl()
      end, {
        buffer = buf,
        desc = 'Kulala: paste request from cURL',
      })
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('kulala-run-keys', { clear = true }),
      pattern = { 'http', 'rest' },
      callback = function(ev)
        attach(ev.buf)
      end,
    })

    -- lazy loads us *on* the FileType event, so this buffer missed the autocmd.
    local buf = vim.api.nvim_get_current_buf()
    if vim.tbl_contains({ 'http', 'rest' }, vim.bo[buf].filetype) then
      attach(buf)
    end
  end,
}

-- vim: ts=2 sts=2 sw=2 et
