-- Iterates through the provided tbl starting from start_index
-- and going around it, first from the left, the right untill
-- there are no more items.
-- ex: {1,2,3,4,5,6}, starting from 3
-- -> 3, 2, 4, 1, 5, 6
local iter_around = function(tbl, start_index)
  local order_index = 0
  local hit_start_limit = false
  local hit_end_limit = false
  return function()
    order_index = order_index + 1
    if order_index > #tbl then
      return
    end

    local is_even = order_index % 2 == 0
    local direction = is_even and -1 or 1
    local incr_around = math.floor(order_index / 2)
    local incr = direction * incr_around
    local index = start_index + incr

    if index < 1 then
      hit_start_limit = true
    elseif index > #tbl then
      hit_end_limit = true
    end

    if hit_start_limit then
      return order_index, tbl[order_index]
    elseif hit_end_limit then
      return order_index, tbl[#tbl - order_index + 1]
    end
    return order_index, tbl[index]
  end
end

return iter_around
