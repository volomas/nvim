-- IntelliJ-style test results window for neotest + neotest-java.
--
-- neotest's summary window is a project-wide test explorer: it always renders
-- the whole adapter tree (every test file in the repository), which is noise
-- when you just ran one class. This module renders only the tests of the run
-- that was just started: live status, duration, and the test output inline
-- (like IntelliJ's Run tool window).
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

--- Durations from the JUnit XML reports, keyed by normalised test id.
--- neotest's results have no timing information, so we read the report files
--- before the adapter deletes them (see M.record_reports).
---@type table<string, number>
local durations = {}
---@type number|nil
local suite_seconds

--- Test ids look like `pkg.Class#method()`; the XML report uses
--- `pkg.Class#method() [1]` for parameterized runs. Compare the stable part.
local function normalise(id)
  return (id:gsub('%s*%[%d+%]$', ''):gsub('%(.*', ''))
end

local function format_seconds(seconds)
  if not seconds then
    return nil
  end
  if seconds < 0.001 then
    return '<1ms'
  end
  if seconds < 1 then
    return string.format('%dms', math.floor(seconds * 1000 + 0.5))
  end
  if seconds < 60 then
    return string.format('%.2fs', seconds)
  end
  return string.format('%dm%02ds', math.floor(seconds / 60), math.floor(seconds % 60))
end

--- Read the JUnit XML reports of a run and remember test/suite durations.
--- Called from the adapter's `results` wrapper in lua/custom/plugins/neotest.lua
--- *before* neotest-java parses (and deletes) them.
---@param reports_dir string|table
function M.record_reports(reports_dir)
  if not reports_dir then
    return
  end
  local dir = tostring(reports_dir)
  local files = vim.fn.glob(dir .. '/TEST-*.xml', false, true)
  if #files == 0 then
    return
  end

  local ok, XmlReader = pcall(require, 'neotest-java.util.xml_reader')
  if not ok then
    return
  end
  local reader = XmlReader.new()

  local map, total = {}, 0
  for _, file in ipairs(files) do
    local parsed = reader.parse(file)
    local suite = parsed.tree and parsed.tree.testsuite
    if suite then
      local attr = suite._attr or {}
      local tests = tonumber(attr.tests) or 0
      local time = tonumber(attr.time)
      if tests > 0 and time then
        total = total + time
      end

      local cases = suite.testcase
      if cases then
        if not vim.isarray(cases) then
          cases = { cases }
        end
        for _, case in ipairs(cases) do
          local a = case._attr or {}
          if a.classname and a.name then
            map[normalise(a.classname .. '#' .. a.name)] = tonumber(a.time) or 0
          end
        end
      end
    end
  end

  durations = map
  suite_seconds = total > 0 and total or nil
end

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

--- One-line summary of a failure: the exception line, plus the assertion detail
--- when the exception line only carries the class name (`...Error:`).
local function short_failure(result)
  local text = result.short
  if type(text) ~= 'string' and type(result.errors) == 'table' and result.errors[1] then
    text = result.errors[1].message
  end
  if type(text) ~= 'string' or text == '' then
    return nil
  end

  local parts = {}
  for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
    line = vim.trim(line)
    if line ~= '' then
      parts[#parts + 1] = line
    end
    if #parts == 2 then
      break
    end
  end
  if not parts[1] then
    return nil
  end

  local msg = parts[1]
  if #parts > 1 and msg:match ':$' then
    msg = msg .. ' ' .. parts[2]
  end
  return msg
end

--- Drop the bookkeeping neotest-java puts in every output file.
---
--- JUnit's XML report writes a `unique-id:` / `display-name:` block at the top
--- of each test's `<system-out>` (even with `--details=none`), and
--- neotest-java joins the chunks of that output with a `=====` separator and
--- appends `Test passed` to every passing test. None of that is the test's own
--- log, so strip it and keep only what the test actually printed.
local function clean_output(lines)
  local kept = {}
  for _, line in ipairs(lines) do
    local trimmed = line:gsub('^%s+', '')
    local noise = trimmed:match '^unique%-id: %[' or trimmed:match '^display%-name: ' or trimmed:match '^=+$'
    if not noise then
      kept[#kept + 1] = line
    end
  end
  while kept[1] and kept[1]:match '^%s*$' do
    table.remove(kept, 1)
  end
  while kept[#kept] and kept[#kept]:match '^%s*$' do
    table.remove(kept)
  end
  if kept[#kept] and kept[#kept]:match '^%s*Test passed%s*$' then
    table.remove(kept)
  end
  return kept
end

--- Lines of a test's captured output (stdout/stderr/stack trace).
local function output_lines(p, result)
  local file = result.output
  if type(file) ~= 'string' or file == '' then
    return {}
  end
  p.output_cache = p.output_cache or {}
  local cached = p.output_cache[file]
  if cached then
    return cached
  end
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok or type(lines) ~= 'table' then
    lines = {}
  end
  lines = clean_output(lines)
  if #lines == 0 then
    lines = { '(no output)' }
  elseif #lines > 400 then
    lines = vim.list_slice(lines, 1, 400)
    lines[#lines + 1] = '… output truncated'
  end
  p.output_cache[file] = lines
  return lines
end

--- How long the run took, in seconds. The JUnit suite time is the test
--- execution time; fall back to wall clock if the reports were not available.
local function total_seconds(p)
  if suite_seconds then
    return suite_seconds
  end
  if p.started_at then
    local stop = p.finished_at or vim.uv.now()
    return (stop - p.started_at) / 1000
  end
  return nil
end

--- Append a right-aligned duration to a row.
local function with_duration(left, seconds, width)
  local suffix = format_seconds(seconds)
  if not suffix then
    return left:sub(1, math.max(width - 1, 10))
  end
  local avail = math.max(width - #suffix - 2, 10)
  if vim.fn.strdisplaywidth(left) > avail then
    left = left:sub(1, avail)
  end
  local pad = math.max(width - vim.fn.strdisplaywidth(left) - #suffix, 1)
  return left .. string.rep(' ', pad) .. suffix
end

--- Header line, one line per test (plus inline output when expanded).
local function build(p)
  local results = results_of(p)
  local width = valid(p) and vim.api.nvim_win_get_width(p.win) or 100
  local counts = { passed = 0, failed = 0, skipped = 0, running = 0, pending = 0 }
  local lines, line_test, line_kind = {}, {}, {}

  if not p.tests then
    lines[1] = string.format('%s  ·  discovering tests…', p.title or 'tests')
  elseif #p.tests == 0 then
    lines[1] = string.format('%s  ·  no tests found', p.title or 'tests')
  else
    local all_done = true
    for _, test in ipairs(p.tests) do
      local status = status_of(p, test.id, results)
      if status == 'running' or status == 'pending' then
        all_done = false
      end
      counts[status] = (counts[status] or 0) + 1
      local left = string.format('%s %s', ICONS[status] or '?', test.name)
      lines[#lines + 1] = with_duration(left, durations[normalise(test.id)], width)
      line_test[#lines] = test
      line_kind[#lines] = status

      local result = results[test.id]
      if result and status == 'failed' then
        local msg = short_failure(result)
        if msg then
          lines[#lines + 1] = '    ' .. msg
          line_test[#lines] = test
          line_kind[#lines] = 'failed'
        end
      end

      if result and p.expanded and p.expanded[test.id] then
        for _, line in ipairs(output_lines(p, result)) do
          lines[#lines + 1] = '    ' .. line
          line_test[#lines] = test
          line_kind[#lines] = 'output'
        end
      end
    end
    p.finished_at = all_done and (p.finished_at or vim.uv.now()) or nil

    local time = format_seconds(total_seconds(p))
    local header = string.format('%s  ·  %d passed  %d failed  %d total%s', p.title, counts.passed, counts.failed, #p.tests, time and ('  ·  ' .. time) or '')
    table.insert(lines, 1, header:sub(1, math.max(width - 1, 10)))
    local shifted_test, shifted_kind = { nil }, { 'header' }
    for i = 1, #line_test do
      shifted_test[i + 1] = line_test[i]
    end
    for i = 1, #line_kind do
      shifted_kind[i + 1] = line_kind[i]
    end
    line_test, line_kind = shifted_test, shifted_kind
  end

  return lines, line_test, line_kind
end

local function render(p)
  if not valid(p) then
    return
  end
  local lines, line_test, line_kind = build(p)
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
  -- grow/shrink with the content (expanded output needs the room)
  pcall(vim.api.nvim_win_set_height, p.win, math.min(math.max(#lines + 1, 5), 40))
  vim.api.nvim_buf_clear_namespace(p.buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(p.buf, ns, 'Title', 0, 0, -1)

  local results = results_of(p)
  for lnum = 1, #lines do
    local kind = line_kind[lnum]
    local test = line_test[lnum]
    if kind == 'output' then
      vim.api.nvim_buf_add_highlight(p.buf, ns, 'Comment', lnum - 1, 0, -1)
    elseif test then
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

--- Filetypes that look like normal windows but are sidebars / tool panels.
--- They must never receive the test file: replacing their buffer is what made
--- the layout shuffle and flicker.
local SIDEBAR_FILETYPES = {
  NvimTree = true,
  nvimtree = true,
  ['neo-tree'] = true,
  oil = true,
  netrw = true,
  help = true,
  lazy = true,
  mason = true,
  trouble = true,
  minifiles = true,
  ['snacks_dashboard'] = true,
  ['snacks_picker_list'] = true,
  ['snacks_picker_input'] = true,
  ['snacks_terminal'] = true,
  ['java-test-results'] = true,
  ['neotest-summary'] = true,
  ['neotest-output'] = true,
  ['neotest-output-panel'] = true,
}

local function is_sidebar(buf)
  local ft = vim.bo[buf].filetype
  if SIDEBAR_FILETYPES[ft] or ft:match '^dap' or ft:match '^neotest' then
    return true
  end
  return false
end

--- A window that is actually editing a file.
local function is_editor_window(p, win)
  if win == p.win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  if vim.api.nvim_win_get_config(win).relative ~= '' then
    return false -- floating window
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.api.nvim_buf_get_name(buf) == '' then
    return false -- scratch / dashboard buffer
  end
  if vim.bo[buf].buftype ~= '' then
    return false -- terminal, quickfix, prompt, ...
  end
  return not is_sidebar(buf)
end

--- Editor windows in this tabpage, most recently used first.
---@return integer[]
local function editor_windows(p)
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor_window(p, win) then
      wins[#wins + 1] = win
    end
  end
  -- the window the panel was opened from is the best default
  for i, win in ipairs(wins) do
    if win == p.editor_win then
      table.remove(wins, i)
      table.insert(wins, 1, win)
      break
    end
  end
  return wins
end

--- Windows among `wins` that already display `path`.
---@return integer[]
local function windows_showing(wins, path)
  local target = vim.fn.bufnr(vim.fn.fnamemodify(path, ':p'))
  if target == -1 then
    return {}
  end
  local found = {}
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_buf(win) == target then
      found[#found + 1] = win
    end
  end
  return found
end

local LABELS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

--- Let the user pick one of `wins` by pressing its letter (A, B, C, …),
--- like Vim's window letters. Returns nil when cancelled.
---@param wins integer[]
---@return integer|nil
local function pick_window(wins)
  local floats, by_label = {}, {}
  for i, win in ipairs(wins) do
    local label = LABELS:sub(i, i)
    if label == '' then
      break
    end
    by_label[label:lower()] = win
    local pos = vim.api.nvim_win_get_position(win)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { label })
    local ok, float = pcall(vim.api.nvim_open_win, buf, false, {
      relative = 'editor',
      row = pos[1] + 1,
      col = pos[2] + 2,
      width = 1,
      height = 1,
      style = 'minimal',
      border = 'single',
      noautocmd = true,
      zindex = 200,
    })
    if ok then
      vim.api.nvim_set_option_value('winhl', 'Normal:Visual,Border:Visual', { win = float })
      floats[#floats + 1] = float
    end
  end

  vim.cmd.redraw()
  local key = vim.fn.getcharstr()
  for _, float in ipairs(floats) do
    pcall(vim.api.nvim_win_close, float, true)
  end
  vim.cmd.redraw()

  if key == '' or key == '\27' then -- <Esc>
    return nil
  end
  return by_label[key:lower()]
end

--- Open the test in the editor, leaving the results window in place.
---
--- Only real file-editing windows are candidates: sidebars (nvim-tree, oil, …),
--- terminals, quickfix and the test panels are skipped. When several remain,
--- the user picks one by its letter instead of guessing.
local function jump_to(p, test)
  if not test or not test.path then
    return
  end
  -- neotest positions store `range` as { start_row, start_col, end_row, end_col }
  -- (0-based rows, as returned by treesitter's node:range()).
  local row = (test.range and test.range[1]) or 0
  local path = test.path
  local target = vim.fn.fnamemodify(path, ':p')

  local wins = editor_windows(p)
  local showing = windows_showing(wins, path)

  local win
  if #showing == 1 then
    win = showing[1] -- already visible: just move the cursor, no reload
  elseif #wins == 1 then
    win = wins[1]
  elseif #wins > 1 then
    win = pick_window(wins)
    if not win then
      return -- cancelled
    end
  else
    -- No editor window at all (the panel is the only one): open above it.
    vim.cmd 'aboveleft split'
    win = vim.api.nvim_get_current_win()
  end

  p.editor_win = win
  vim.api.nvim_set_current_win(win)

  local buf = vim.api.nvim_win_get_buf(win)
  local shown = vim.api.nvim_buf_get_name(buf)
  if shown ~= target then
    vim.cmd.edit(vim.fn.fnameescape(path))
  end
  pcall(vim.api.nvim_win_set_cursor, win, { row + 1, 0 })
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

local function toggle_output(p)
  local test = test_at_cursor(p)
  if not test then
    return
  end
  p.expanded = p.expanded or {}
  if p.expanded[test.id] then
    p.expanded[test.id] = nil
  else
    p.expanded[test.id] = true
  end
  render(p)
end

local function set_keymaps(p)
  local map = function(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = p.buf, desc = desc, silent = true })
  end

  -- expand/collapse the test's captured output inline (IntelliJ style)
  map('<CR>', function()
    toggle_output(p)
  end, 'Test: toggle output')
  -- full output in a floating terminal (neotest's own window)
  map('o', function()
    local test = test_at_cursor(p)
    if test then
      require('neotest').output.open { position_id = test.id }
    end
  end, 'Test: output in floating window')
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
    jump_to(p, test_at_cursor(p))
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
    local current = vim.api.nvim_get_current_win()
    if current ~= panel.win then
      panel.editor_win = current
    end
    panel.title = title
    panel.tests = nil
    panel.last_lines = nil
    panel.args = nil
    panel.scope = nil
    panel.strategy = nil
    panel.started_at = nil
    panel.finished_at = nil
    panel.output_cache = nil
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

  local p = { buf = buf, win = win, title = title, line_test = {}, client = neotest_client(), editor_win = prev_win }
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
    p.started_at = vim.uv.now()
    p.finished_at = nil
    p.output_cache = nil
    p.expanded = nil
    render(p)
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

  -- timings belong to the run that is about to start
  durations = {}
  suite_seconds = nil

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

  durations = {}
  suite_seconds = nil

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
      p.started_at = vim.uv.now()
      p.finished_at = nil
      p.output_cache = nil
      p.expanded = nil
      render(p)
    end
    n.run.run_last()
  end)
end

return M
