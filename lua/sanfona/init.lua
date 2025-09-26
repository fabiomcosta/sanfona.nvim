local OrderedSet = require('sanfona.ordered_set')
local iter_around = require('sanfona.iter_around')
local win = require('sanfona.win')
local config = require('sanfona.config')
local extras = require('sanfona.extras')

local win_focus_history = OrderedSet.new()

local M = extras

local function indexof(tbl, predicate)
  local index = vim.fn.indexof(tbl, predicate)
  -- not found
  if index == -1 then
    return
  end
  -- All vim.fn.* functions are 0 indexed, lol
  return index + 1
end

-- Rebuilds the focus_history OrderedSet making sure to keep the existing
-- order as well as removing any window that is not supposed to be controlled
-- by sanfona (the ones returned by win.list_sanfona_wins()).
local rebuild_focus_history = function()
  local windows = win.list_sanfona_wins()
  local win_history = OrderedSet.new()
  for win_id in win_focus_history:items() do
    if vim.list_contains(windows, win_id) then
      win_history:append(win_id)
    end
  end
  return win_history
end

function M.resize()
  local windows = win.list_sanfona_wins()

  if #windows < 2 then
    return
  end

  local expanded_win_count = win.get_expanded_win_count(windows)

  if win_focus_history:len() >= expanded_win_count then
    local focus_history = win_focus_history:slice(-expanded_win_count)
    for _, win_id in pairs(windows) do
      if vim.list_contains(focus_history, win_id) then
        win.expand(win_id)
      else
        win.collapse(win_id)
      end
    end
  else
    local focused_win_id = win_focus_history:first()
    local focused_win_index = indexof(windows, function(_, win_id)
      return win_id == focused_win_id
    end)

    for i, win_id in iter_around(windows, focused_win_index) do
      if i <= expanded_win_count then
        win.expand(win_id)
        win_focus_history:append(win_id)
      else
        win.collapse(win_id)
      end
    end
  end

  vim.api.nvim_exec2('wincmd =', { output = false })
end

function M.setup(cfg)
  -- Needed so that we can collapse windows down to 1 column.
  vim.o.winwidth = 1
  vim.o.winminwidth = 1

  config(cfg)

  local augroup = vim.api.nvim_create_augroup('Sanfona', { clear = true })
  local create_autocmd = function(events, callback)
    vim.api.nvim_create_autocmd(events, {
      group = augroup,
      callback = callback,
    })
  end

  -- WinEnter and WinNew are silently called for each open window before
  -- VimEnter, which is unexpected and very confusing, so we ignore those
  -- events and only re-enable them after VimEnter.
  local ignore_mksession = true

  --
  local force_relayout = false

  create_autocmd('WinNew', function()
    if ignore_mksession then
      return
    end
    -- TODO: Is there a way to get the if of the newly created window?
    -- nvim_get_current_win returns the id of the currently focuesd window
    -- not from the new one.
    force_relayout = true
  end)
  create_autocmd('WinClosed', function(event)
    local closed_win_id = tonumber(event.match)
    if closed_win_id == nil or not vim.api.nvim_win_is_valid(closed_win_id) then
      return
    end
    if win.is_float(closed_win_id) then
      return
    end
    if not win.is_top_positioned(closed_win_id) then
      return
    end
    force_relayout = true
  end)
  create_autocmd('WinEnter', function()
    local current_win_id = vim.api.nvim_get_current_win()
    if ignore_mksession then
      -- Setting winfixheight without vim.schedule will end up making it so
      -- on load all the windows become flat with height 1
      vim.schedule(function()
        win.preserve_height(current_win_id)
      end)
      return
    end
    if win.is_float(current_win_id) or win.is_bottom_sheet(current_win_id) then
      return
    end

    if force_relayout then
      win_focus_history = rebuild_focus_history()
    end

    local win_topmost_id = win.get_topmost_id()
    win_focus_history:append(win_topmost_id)

    if not force_relayout then
      -- When moving to an already expanded window, there is no need to
      -- relayout.
      local width = vim.api.nvim_win_get_width(win_topmost_id)
      if width > 1 then
        return
      end
    else
      force_relayout = false
    end

    M.resize()
  end)
  create_autocmd('VimEnter', function()
    ignore_mksession = false
    win_focus_history:append(win.get_topmost_id())
    M.resize()
  end)
  create_autocmd('VimResized', function()
    M.resize()
  end)
end

function M.debug()
  local windows = win.list_sanfona_wins()
  local expanded_win_count = win.get_expanded_win_count(windows)
  local data = {
    current_win_id = vim.api.nvim_get_current_win(),
    expanded_win_count = expanded_win_count,
    focus_history = win_focus_history:slice(-100),
    windows = windows,
    config = config,
  }
  print(vim.inspect(data))
  return data
end

return M
