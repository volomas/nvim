-- Single-line LSP progress summary for the statusline.
--
-- `client.progress` is a ringbuf and iterating it consumes (pops) the entries,
-- so it cannot be used to read current state. Instead we track the `$/progress`
-- tokens ourselves: add on `begin`/`report`, drop on `end`.
local M = {}

--- @class lsp.ProgressTask
--- @field client_id integer
--- @field seq integer
--- @field title string
--- @field message string?
--- @field percentage number?

--- In-flight progress tasks, keyed by "<client_id>:<token>".
--- @type table<string, lsp.ProgressTask>
local tasks = {}

--- Monotonic counter so the rendered line keeps a stable order.
local seq = 0

--- Render one task as a string.
--- @param task lsp.ProgressTask
--- @return string
local function format(task)
  local text = task.title
  if task.message and task.message ~= '' then
    text = text .. ': ' .. task.message
  end
  if type(task.percentage) == 'number' then
    text = string.format('%s %d%%', text, task.percentage)
  end
  return text
end

--- All in-flight progress messages, joined onto a single line.
--- @return string
function M.status()
  local parts = {}
  for _, task in pairs(tasks) do
    -- Drop tasks left behind by a server that went away mid-progress.
    if vim.lsp.get_client_by_id(task.client_id) then
      local text = format(task)
      if text ~= '' then
        parts[#parts + 1] = { seq = task.seq, text = text }
      end
    end
  end
  table.sort(parts, function(a, b)
    return a.seq < b.seq
  end)

  -- Dedupe equal messages (jdtls reuses titles across tokens), keeping first.
  local texts, seen = {}, {}
  for _, part in ipairs(parts) do
    if not seen[part.text] then
      seen[part.text] = true
      texts[#texts + 1] = part.text
    end
  end
  return table.concat(texts, ' · ')
end

vim.api.nvim_create_autocmd('LspProgress', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-progress', { clear = true }),
  callback = function(event)
    local data = event.data
    local value = data.params.value
    -- Not every server sends well-formed work-done progress.
    if type(value) ~= 'table' or not value.kind then
      return
    end

    local key = tostring(data.client_id) .. ':' .. tostring(data.params.token)
    if value.kind == 'end' then
      tasks[key] = nil
    else
      local task = tasks[key]
      if not task then
        seq = seq + 1
        task = { client_id = data.client_id, title = '', seq = seq }
      end
      task.title = value.title or task.title
      task.message = value.message or task.message
      if type(value.percentage) == 'number' then
        task.percentage = value.percentage
      end
      tasks[key] = task
    end

    -- Redraw the statusline. lualine may not be loaded yet.
    pcall(function()
      require('lualine').refresh()
    end)
  end,
})

return M
-- vim: ts=2 sts=2 sw=2 et
