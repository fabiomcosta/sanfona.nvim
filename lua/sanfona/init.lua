local OrderedSet = require('sanfona.ordered_set')
local iter_around = require('sanfona.iter_around')

local config
local win_focus_history = OrderedSet.new()

local M = {}

local win_is_float = function(win_config)
  return win_config.zindex ~= nil or win_config.relative ~= ''
end

local win_is_full_width = function(win_id)
  return vim.fn.winwidth(win_id) == vim.o.columns
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

local win_list_valid_wins = function()
  local windows = {}
  -- TODO[nit]: use vim.fn.filter
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win_id) then
      local win_config = vim.api.nvim_win_get_config(win_id)
      if not win_is_float(win_config) then
        local win_pos = vim.api.nvim_win_get_position(win_id)
        -- Only consider windows positioned at the very top
        if win_pos[1] == 0 then
          table.insert(windows, win_id)
        end
      end
    end
  end
  return windows
end

local win_get_topmost_id = function()
  local current_win_id = vim.api.nvim_get_current_win()
  local current_win_pos = vim.api.nvim_win_get_position(current_win_id)

  -- TODO[possible-bug]: if there is a tabs plugin, y might not be 0,
  -- we need to test that.

  -- If current win is already top most, return it
  if current_win_pos[1] == 0 then
    return current_win_id
  end

  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local win_pos = vim.api.nvim_win_get_position(win_id)
    if win_pos[1] == 0 and win_pos[2] == current_win_pos[2] then
      return win_id
    end
  end

  -- Should never happen, but seems like a fine default.
  return current_win_id
end

function M.resize()
  -- Needed so that we can collapse windows down to 1 column.
  vim.o.winwidth = 1
  vim.o.winminwidth = 1

  local max_width = vim.o.columns
  local max_visible_splits = math.floor(max_width / config.min_width)

  local windows = win_list_valid_wins()

  if win_focus_history:len() >= max_visible_splits then
    local focus_history = win_focus_history:slice(-max_visible_splits)
    for _, win_id in pairs(windows) do
      if vim.list_contains(focus_history, win_id) then
        win_expand(win_id)
      else
        win_collapse(win_id)
      end
    end
  elseif win_focus_history:len() == 1 then
    local focused_win_id = win_focus_history:first()
    local focused_win_index = vim.fn.indexof(windows, function(_, win_id)
      return win_id == focused_win_id
    end)
    -- All vim.fn.* functions are 0 indexed, lol
    focused_win_index = focused_win_index + 1

    for i, win_id in iter_around(windows, focused_win_index) do
      if i <= max_visible_splits then
        win_expand(win_id)
      else
        win_collapse(win_id)
      end
    end
  else
    assert(false)
  end

  vim.api.nvim_exec2('wincmd =', { output = false })
end

function M.setup(cfg)
  config = vim.tbl_deep_extend('force', {
    min_width = vim.o.colorcolumn,
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

  create_autocmd('WinEnter', function()
    local current_win_id = vim.api.nvim_get_current_win()
    if ignore_mksession then
      if win_is_full_width(current_win_id) then
        vim.schedule(function()
          win_set_local_option(current_win_id, 'winfixheight', true)
        end)
      end
      return
    end
    if win_is_full_width(current_win_id) then
      return
    end

    local win_topmost_id = win_get_topmost_id()
    win_focus_history:append(win_topmost_id)

    -- When moving to an already expanded window, there is no need to
    -- relayout.
    local width = vim.api.nvim_win_get_width(win_topmost_id)
    if width > 1 then
      return
    end

    M.resize()
  end)
  create_autocmd('VimEnter', function()
    ignore_mksession = false
    win_focus_history:append(win_get_topmost_id())
    M.resize()
  end)
  create_autocmd('WinNew', function()
    if ignore_mksession then
      return
    end

    -- Ignore WinNew events for popups
    local win_config = vim.api.nvim_win_get_config(0)
    if win_is_float(win_config) then
      return
    end

    win_focus_history:append(win_get_topmost_id())
    M.resize()
  end)
  create_autocmd('WinClosed', function(event)
    local closed_win_id = tonumber(event.match)
    if closed_win_id == nil or not vim.api.nvim_win_is_valid(closed_win_id) then
      return
    end

    local win_config = vim.api.nvim_win_get_config(closed_win_id)
    if win_is_float(win_config) then
      return
    end

    win_focus_history:remove(closed_win_id)
    M.resize()
  end)
  create_autocmd('VimResized', M.resize)
end

return M
