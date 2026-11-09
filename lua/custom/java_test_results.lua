-- IntelliJ-style test results window for neotest + neotest-java.
--
-- neotest's summary window is a project-wide test explorer: it always renders
-- the whole adapter tree (every test file in the repository), which is noise
-- when you just ran one class. This module renders only the tests of the run
-- that was just started, with their live status, and keymaps to open each
-- test's output (logs / stack trace).
local M = {}

local ns = vim.api.nvim_create_namespace 'java-test-results'

local ICONS = { passed = '󰸞', failed = '󰅖', skipped = '󰜺', running = '…', pending = '·' }
local HIGHLIGHTS = {
  passed = 'NeotestPassed',
  failed = 'NeotestFailed',
  skipped = 'NeotestSkipped',
  running = 'NeotestRunning',
  pending = 'NeotestTest',
}

--- Currently open panel. Only one is kept; starting a new run reuses it.
---@type table|nil
local panel

--- neotest does not expose `client:get_results()` publicly. The public `state`
--- consumer closes over the tracker, and the tracker holds the client, so read
--- it from there. Everything is guarded: if neotest changes its internals the
--- window still lists the tests, it just loses the live status.
local function neotest_client()
  local ok, api = pcall(require, 'neotest')
  if not ok or type(api) ~= 'table' or type(api.state) ~= 'table' then
    return nil
  end
  local fn = api.state.adapter_ids
  if type(fn) ~= 'function' then
    return nil
  end
  local _, tracker = debug.getupvalue(fn, 1)
  if type(tracker) ~= 'table' then
    return nil
  end
  return tracker.client
end

local function valid(p)
  return p ~= nil and vim.api.nvim_buf_is_valid(p.buf) and vim.api.nvim_win_is_valid(p.win)
end

local function results_of(p)
  if not p.client then
    return {}
  end
  local ok, res = pcall(p.client.get_results, p.client, p.adapter_id)
  return ok and type(res) == 'table' and res or {}
end

local function status_of(p, id, results)
  if p.client and p.client:is_running(id, { adapter = p.adapter_id }) then
    return 'running'
  end
  local result = results[id]
  if result and result.status then
    return result.status
  end
  return 'pending'
end

--- First line of a failure message.
local function short_failure(result)
  local text = result.short
  if type(text) ~= 'string' and type(result.errors) == 'table' and result.errors[1] then
    text = result.errors[1].message
  end
  if type(text) ~= 'string' or text == '' then
    return nil
  end
  return vim.split(text, '\n', { plain = true })[1]
end

--- Header line, one line per test, and an indented line with the failure
--- message for failing tests.
local function build(p)
  local results = results_of(p)
  local counts = { passed = 0, failed = 0, skipped = 0, running = 0, pending = 0 }
  local lines, line_test = {}, {}

  if not p.tests then
    lines[1] = string.format('%s  ·  discovering tests…', p.title or 'tests')
  elseif #p.tests == 0 then
    lines[1] = string.format('%s  ·  no tests found', p.title or 'tests')
  else
    for _, test in ipairs(p.tests) do
      local status = status_of(p, test.id, results)
      counts[status] = (counts[status] or 0) + 1
      lines[#lines + 1] = string.format('%s %s', ICONS[status] or '?', test.name)
      line_test[#lines] = test

      local result = results[test.id]
      if result and status == 'failed' then
        local msg = short_failure(result)
        if msg then
          lines[#lines + 1] = '    ' .. msg
          line_test[#lines] = test
        end
      end
    end

    local width = valid(p) and vim.api.nvim_win_get_width(p.win) or 80
    local header = string.format('%s  ·  %d passed  %d failed  %d skipped  %d total', p.title, counts.passed, counts.failed, counts.skipped, #p.tests)
    table.insert(lines, 1, header:sub(1, math.max(width - 1, 10)))
  end

  return lines, line_test
end

local function render(p)
  if not valid(p) then
    return
  end
  local lines, line_test = build(p)
  -- Polling refreshes this window; skip the write when nothing changed so the
  -- buffer does not flicker.
  if p.last_lines and vim.deep_equal(p.last_lines, lines) then
    p.line_test = line_test
    return
  end
  p.last_lines = lines
  vim.bo[p.buf].modifiable = true
  vim.api.nvim_buf_set_lines(p.buf, 0, -1, false, lines)
  vim.bo[p.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(p.buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(p.buf, ns, 'Title', 0, 0, -1)

  local results = results_of(p)
  for lnum = 1, #lines do
    local test = line_test[lnum]
    if test then
      local hl = HIGHLIGHTS[status_of(p, test.id, results)]
      if hl then
        vim.api.nvim_buf_add_highlight(p.buf, ns, hl, lnum - 1, 0, -1)
      end
    end
  end

  p.line_test = line_test
end

local function test_at_cursor(p)
  if not valid(p) then
    return nil
  end
  local lnum = vim.api.nvim_win_get_cursor(p.win)[1]
  return p.line_test and p.line_test[lnum] or nil
end

local function jump_to(test)
  if not test or not test.path then
    return
  end
  -- neotest positions store `range` as { start_row, start_col, end_row, end_col }
  -- (0-based rows, as returned by treesitter's node:range()).
  local row = (test.range and test.range[1]) or 0
  vim.cmd.edit(vim.fn.fnameescape(test.path))
  pcall(vim.api.nvim_win_set_cursor, 0, { row + 1, 0 })
  vim.cmd 'normal! zz'
end

local function stop_polling(p)
  if p.timer then
    p.timer:stop()
    if not p.timer:is_closing() then
      p.timer:close()
    end
    p.timer = nil
  end
end

--- neotest's client is not reachable from user config, so this window polls the
--- public state/results API instead of listening to neotest's (internal) events.
local function start_polling(p)
  stop_polling(p)
  local timer = vim.uv.new_timer()
  p.timer = timer
  timer:start(0, 300, function()
    vim.schedule(function()
      if not valid(p) or panel ~= p then
        stop_polling(p)
        return
      end
      render(p)
    end)
  end)
end

local function set_keymaps(p)
  local map = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = p.buf, desc = desc, silent = true })
  end

  -- full output / stack trace of the test under the cursor (neotest float)
  map('<CR>', function()
    local test = test_at_cursor(p)
    if test then
      require('neotest').output.open { position_id = test.id }
    end
  end, 'Test: show output')
  map('o', function()
    local test = test_at_cursor(p)
    if test then
      require('neotest').output.open { position_id = test.id, short = true }
    end
  end, 'Test: show short output')
  map('r', function()
    local test = test_at_cursor(p)
    if test then
      M.run(test.id)
    end
  end, 'Test: rerun')
  map('R', function()
    M.rerun()
  end, 'Test: rerun all in this window')
  map('i', function()
    jump_to(test_at_cursor(p))
  end, 'Test: jump to source')
  map('q', function()
    pcall(vim.api.nvim_win_close, p.win, true)
  end, 'Test: close window')
end

--- Open (or reuse) the results window.
---@param title string
---@return table
local function open_panel(title)
  if valid(panel) then
    panel.title = title
    panel.tests = nil
    panel.last_lines = nil
    panel.args = nil
    panel.scope = nil
    panel.strategy = nil
    panel.client = neotest_client()
    render(panel)
    return panel
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'java-test-results'
  vim.api.nvim_buf_set_name(buf, 'Java Test Results')

  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd 'botright 8split'
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(prev_win) -- keep focus in the editor

  local p = { buf = buf, win = win, title = title, line_test = {}, client = neotest_client() }
  panel = p
  set_keymaps(p)
  start_polling(p)

  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      stop_polling(p)
      if panel == p then
        panel = nil
      end
    end,
  })

  render(p)
  return p
end

--- Tree for a run request, plus the adapter it belongs to.
--- (`neotest.run.get_tree_from_args` drops the adapter, and we need it to read
--- that adapter's results.)
---@return table|nil, string|nil
local function resolve_tree(client, args)
  local target = type(args) == 'table' and args[1] or args
  if type(target) == 'string' then
    local id = require('neotest.lib').files.path.real(target) or target
    return client:get_position(id, type(args) == 'table' and args or {})
  end
  local path = vim.api.nvim_buf_get_name(0)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  return client:get_nearest(path, row, type(args) == 'table' and args or {})
end

--- Tests covered by a tree.
---@return table[]
local function tests_from(tree)
  local tests = {}
  for _, pos in tree:iter() do
    if pos.type == 'test' then
      tests[#tests + 1] = { id = pos.id, name = pos.name, path = pos.path, range = pos.range }
    end
  end
  return tests
end

--- Collect the tests a tree covers and start `run()`.
local function start(p, run)
  require('nio').run(function()
    local n = require 'neotest'
    local client = p.client or neotest_client()
    p.client = client
    local tree, adapter_id
    if client then
      tree, adapter_id = resolve_tree(client, p.args)
    end
    if not tree then
      p.tests = {}
      render(p)
      vim.notify('No tests found', vim.log.levels.WARN)
      return
    end
    p.adapter_id = adapter_id
    local tests = tests_from(tree)
    p.tests = tests
    local node = tree:data()
    p.scope = node.id
    p.title = node.type == 'test' and vim.fn.fnamemodify(node.path, ':t') or node.name
    render(p)
    pcall(vim.api.nvim_win_set_height, p.win, math.max(5, math.min(#tests + 3, 20)))
    run()
  end)
end

--- Run tests for `args` (same argument shapes as `require('neotest').run.run`).
---@param args? string|table
function M.run(args)
  local n = require 'neotest'
  local target = type(args) == 'table' and args[1] or args
  local title = 'tests'
  if type(target) == 'string' and vim.endswith(target, '.java') then
    title = vim.fn.fnamemodify(target, ':t')
  end

  local p = open_panel(title)
  p.args = args
  p.strategy = type(args) == 'table' and args.strategy or nil

  -- neotest discovers test positions in the background on BufAdd. Running
  -- before that finishes just reports "No tests found", so wait for the file
  -- (bounded) before asking for its tree.
  local client = neotest_client()
  if client and type(target) == 'string' and vim.endswith(target, '.java') then
    local path = require('neotest.lib').files.path.real(target) or target
    require('nio').run(function()
      local waited = 0
      while not client:get_position(path) and waited < 30000 do
        require('nio').sleep(200)
        waited = waited + 200
      end
      start(p, function()
        n.run.run(args)
      end)
    end)
    return
  end

  start(p, function()
    n.run.run(args)
  end)
end

--- Re-run whatever the window currently shows.
function M.rerun()
  if not valid(panel) or not panel.scope then
    return
  end
  local args = panel.scope
  if panel.strategy then
    args = { panel.scope, strategy = panel.strategy }
  end
  M.run(args)
end

--- `\u`: rerun the last test, same window handling.
function M.run_last()
  local n = require 'neotest'
  local position_id, last_args = n.run.get_last_run()
  if not position_id then
    vim.notify('No tests run yet', vim.log.levels.WARN)
    return
  end

  local title = 'tests'
  if vim.endswith(position_id, '.java') then
    title = vim.fn.fnamemodify(position_id, ':t')
  end
  local p = open_panel(title)
  p.args = position_id
  p.scope = position_id
  p.strategy = last_args.strategy

  require('nio').run(function()
    local client = p.client
    local tree, adapter_id = client and client:get_position(position_id, last_args)
    if tree then
      p.adapter_id = adapter_id
      p.tests = tests_from(tree)
      local node = tree:data()
      p.scope = node.id
      p.title = node.type == 'test' and vim.fn.fnamemodify(node.path, ':t') or node.name
      render(p)
    end
    n.run.run_last()
  end)
end

return M
