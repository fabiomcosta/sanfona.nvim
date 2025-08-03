local OrderedSet = require('sanfona.ordered_set')
local iter_around = require('sanfona.iter_around')

local config
local win_focus_history = OrderedSet.new()

-- Each collapsed window uses 1 column of width for itself and 1 column for
-- its border.
local COLLAPSED_WIN_WIDTH = 2

-- The numbers column can vary in width, but most commonly it will be 3
-- characters (up to 999) then there is an extra empty character and one more
-- for windows's borders.
local EXPANDED_WIN_EXTRA_WIDTH = 5

local M = {}

local indexof = function(tbl, predicate)
  local index = vim.fn.indexof(tbl, predicate)
  -- not found
  if index == -1 then
    return
  end
  -- All vim.fn.* functions are 0 indexed, lol
  return index + 1
end

local win_is_float = function(win_id)
  local win_config = vim.api.nvim_win_get_config(win_id)
  return win_config.zindex ~= nil or win_config.relative ~= ''
end

local win_is_full_width = function(win_id)
  return vim.fn.winwidth(win_id) == vim.o.columns
end

local win_is_top_positioned = function(win_id)
  local win_pos = vim.api.nvim_win_get_position(win_id)
  return win_pos[1] == 0
end

-- "best guess" on if the window is a bottom_sheet
local win_is_bottom_sheet = function(win_id)
  return win_is_full_width(win_id) and not win_is_top_positioned(win_id)
end

local win_set_local_option = function(win_id, name, value)
  vim.api.nvim_set_option_value(name, value, { scope = 'local', win = win_id })
end

local win_collapse = function(win_id)
  win_set_local_option(win_id, 'winfixwidth', true)
  vim.api.nvim_win_set_width(win_id, 1)
end

local win_expand = function(win_id)
  win_set_local_option(win_id, 'winfixwidth', false)
  vim.api.nvim_win_set_width(win_id, vim.o.columns)
end

-- Setting winfixheight makes sure that when `wincmd =` runs the heights are
-- preserved, which is generaly the deserved behavior.
local win_preserve_height = function(win_id)
  win_set_local_option(win_id, 'winfixheight', true)
end

local win_list_sanfona_wins = function()
  return vim.fn.filter(vim.api.nvim_list_wins(), function(_, win_id)
    if not vim.api.nvim_win_is_valid(win_id) then
      return false
    end
    if win_is_float(win_id) then
      return false
    end
    return win_is_top_positioned(win_id)
  end)
end

local win_get_topmost_id = function()
  local current_win_id = vim.api.nvim_get_current_win()

  -- TODO[possible-bug]: if there is a tabs plugin, y might not be 0,
  -- we need to test that.

  -- If current win is already top most, return it
  if win_is_top_positioned(current_win_id) then
    return current_win_id
  end

  local current_win_pos = vim.api.nvim_win_get_position(current_win_id)
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local win_pos = vim.api.nvim_win_get_position(win_id)
    if win_pos[1] == 0 and win_pos[2] == current_win_pos[2] then
      return win_id
    end
  end

  -- Should never happen, but seems like a fine default.
  return current_win_id
end

local get_max_visible_wins = function(wins)
  local viewport_width = vim.o.columns
  local max_visible_wins = math.floor(viewport_width / config.min_width)

  for visible_wins = max_visible_wins, 1, -1 do
    local collapsed_width = (#wins - visible_wins) * COLLAPSED_WIN_WIDTH
    local expanded_extra_width = visible_wins * EXPANDED_WIN_EXTRA_WIDTH
    local available_width_for_text = viewport_width
      - collapsed_width
      - expanded_extra_width
    local available_visible_width_per_win = available_width_for_text
      / visible_wins
    if available_visible_width_per_win >= config.min_width then
      return visible_wins
    end
  end

  return max_visible_wins
end

-- Rebuilds the focus_history ordered set making sure to keep the existing
-- order as well as removing any window that is not supposed to be controlled
-- by sanfona (the ones returned by win_list_sanfona_wins()).
local rebuild_focus_history = function()
  local windows = win_list_sanfona_wins()
  local win_history = OrderedSet.new()
  for win_id in win_focus_history:items() do
    if vim.list_contains(windows, win_id) then
      win_history:append(win_id)
    end
  end
  return win_history
end

function M.resize(windows)
  windows = windows or win_list_sanfona_wins()

  if #windows < 2 then
    return
  end

  local max_visible_splits = get_max_visible_wins(windows)

  if win_focus_history:len() >= max_visible_splits then
    local focus_history = win_focus_history:slice(-max_visible_splits)
    for _, win_id in pairs(windows) do
      if vim.list_contains(focus_history, win_id) then
        win_expand(win_id)
      else
        win_collapse(win_id)
      end
    end
  else
    local focused_win_id = win_focus_history:first()
    local focused_win_index = indexof(windows, function(_, win_id)
      return win_id == focused_win_id
    end)

    for i, win_id in iter_around(windows, focused_win_index) do
      if i <= max_visible_splits then
        win_expand(win_id)
        win_focus_history:append(win_id)
      else
        win_collapse(win_id)
      end
    end
  end

  vim.api.nvim_exec2('wincmd =', { output = false })
end

function M.setup(cfg)
  -- Needed so that we can collapse windows down to 1 column.
  vim.o.winwidth = 1
  vim.o.winminwidth = 1

  config = vim.tbl_deep_extend('force', {
    min_width = tonumber(vim.o.colorcolumn) or 80,
  }, cfg)

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
    if win_is_float(closed_win_id) then
      return
    end
    if not win_is_top_positioned(closed_win_id) then
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
        win_preserve_height(current_win_id)
      end)
      return
    end
    if win_is_float(current_win_id) or win_is_bottom_sheet(current_win_id) then
      return
    end

    if force_relayout then
      win_focus_history = rebuild_focus_history()
    end

    local win_topmost_id = win_get_topmost_id()
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
    win_focus_history:append(win_get_topmost_id())
    M.resize()
  end)
  create_autocmd('VimResized', function()
    M.resize()
  end)
end

function M.debug()
  local windows = win_list_sanfona_wins()
  local max_visible_wins = get_max_visible_wins(windows)
  local data = {
    current_win_id = vim.api.nvim_get_current_win(),
    max_visible_wins = max_visible_wins,
    focus_history = win_focus_history:slice(-100),
    windows = windows,
    config = config,
  }
  print(vim.inspect(data))
  return data
end

return M
