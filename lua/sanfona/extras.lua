local win = require('sanfona.win')

local M = {}

local function vim_cmd_exists(cmd_name)
  return vim.fn.exists(':' .. cmd_name) > 1
end

function M.win_focus_up()
  local current_win_id = vim.api.nvim_get_current_win()
  if win.is_bottom_sheet(current_win_id) then
    for _, win_id in ipairs(win.list_sanfona_wins()) do
      if not win.is_collapsed(win_id) then
        return vim.api.nvim_set_current_win(win_id)
      end
    end
  end
  if vim_cmd_exists('TmuxNavigateUp') then
    return vim.cmd('TmuxNavigateUp')
  end
  return vim.cmd('wincmd k')
end

function M.win_close_bottom_sheet()
  for win_nr = vim.fn.winnr('$'), 0, -1 do
    local win_id = vim.fn.win_getid(win_nr)
    if win.is_bottom_sheet(win_id) then
      return vim.api.nvim_win_close(win_id, false)
    end
  end
end

return M
