local config = require('sanfona.config')

-- Each collapsed window uses 1 column of width for itself and 1 column for
-- its border.
local COLLAPSED_WIN_WIDTH = 2

-- The numbers column can vary in width, but most commonly it will be 3
-- characters (up to 999) then there is an extra empty character and one more
-- for windows's borders.
local EXPANDED_WIN_EXTRA_WIDTH = 5

local M = {}

local function set_local_option(win_id, name, value)
  vim.api.nvim_set_option_value(name, value, { scope = 'local', win = win_id })
end

function M.is_float(win_id)
  local win_config = vim.api.nvim_win_get_config(win_id)
  return win_config.zindex ~= nil or win_config.relative ~= ''
end

function M.is_full_width(win_id)
  return vim.fn.winwidth(win_id) == vim.o.columns
end

function M.is_top_positioned(win_id)
  local win_pos = vim.api.nvim_win_get_position(win_id)
  return win_pos[1] == 0
end

-- "best guess" on if the window is a bottom_sheet
function M.is_bottom_sheet(win_id)
  return M.is_full_width(win_id) and not M.is_top_positioned(win_id)
end

function M.collapse(win_id)
  set_local_option(win_id, 'winfixwidth', true)
  vim.api.nvim_win_set_width(win_id, 1)
end

function M.expand(win_id)
  set_local_option(win_id, 'winfixwidth', false)
  vim.api.nvim_win_set_width(win_id, vim.o.columns)
end

-- Setting winfixheight makes sure that when `wincmd =` runs the heights are
-- preserved, which is generaly the deserved behavior.
function M.preserve_height(win_id)
  set_local_option(win_id, 'winfixheight', true)
end

function M.list_sanfona_wins()
  return vim.fn.filter(vim.api.nvim_list_wins(), function(_, win_id)
    if not vim.api.nvim_win_is_valid(win_id) then
      return false
    end
    if M.is_float(win_id) then
      return false
    end
    return M.is_top_positioned(win_id)
  end)
end

function M.get_topmost_id()
  local current_win_id = vim.api.nvim_get_current_win()

  -- TODO[possible-bug]: if there is a tabs plugin, y might not be 0,
  -- we need to test that.

  -- If current win is already top most, return it
  if M.is_top_positioned(current_win_id) then
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

-- Returns how many windows we are supposed to keep visible (expanded).
function M.get_expanded_win_count(wins)
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

return M
