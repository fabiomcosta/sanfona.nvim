-- Copyright (C) 2016 Ivan Baidakou (with some changes)
-- Licence: Artistic License 2.0

local OrderedSet = {}
OrderedSet.__index = OrderedSet

function OrderedSet.new(items)
  local o = {
    node_for = {}, -- k: object, v: node
    head = nil,
    tail = nil,
    capacity = 0,
  }
  setmetatable(o, OrderedSet)
  if items then
    for _, item in pairs(items) do
      o:append(item)
    end
  end
  return o
end

function OrderedSet:_insert(item, operation)
  if self.node_for[item] then
    self:remove(item)
  end
  self.node_for[item] = operation()
  self.capacity = self.capacity + 1
end

function OrderedSet:append(item)
  self:_insert(item, function()
    local prev = self.tail

    local node = {
      _item = item,
      _next = nil,
      _prev = prev,
    }

    if prev then
      local prev_next = prev._next
      prev._next = node
      node._next = prev_next
    end

    if not self.head then
      self.head = node
      self.tail = node
    end

    if not node._next then
      self.tail = node
    end

    return node
  end)
end

function OrderedSet:prepend(item)
  self:_insert(item, function()
    local next = self.head

    local node = {
      _item = item,
      _next = next,
      _prev = nil,
    }

    if next then
      local next_prev = next._prev
      next._prev = node
      node._prev = next_prev
    end

    if not self.tail then
      self.head = node
      self.tail = node
    end

    if not node._prev then
      self.head = node
    end
    return node
  end)
end

function OrderedSet:remove(item)
  local node = self.node_for[item]
  if not node then
    return
  end

  local _prev = node._prev
  local _next = node._next

  if _prev then
    _prev._next = _next
  else
    self.head = _next
  end

  if _next then
    _next._prev = _prev
  else
    self.tail = _prev
  end

  self.node_for[item] = nil
  self.capacity = self.capacity - 1
end

function OrderedSet:__items(reverse)
  local node, next_prop

  if reverse then
    node = self.tail
    next_prop = '_prev'
  else
    node = self.head
    next_prop = '_next'
  end

  return function()
    if node then
      local item = node._item
      node = node[next_prop]
      return item
    end
  end
end

function OrderedSet:items()
  return self:__items()
end

function OrderedSet:ritems()
  return self:__items(true)
end

function OrderedSet:len()
  return self.capacity
end

function OrderedSet:first()
  if self.head then
    return self.head._item
  end
end

function OrderedSet:last()
  if self.tail then
    return self.tail._item
  end
end

function OrderedSet:slice(n)
  -- TODO: only supporting negative for now because that's what I need
  -- but ideally it would support both just for completeness.
  assert(n < 0, 'Only negative slices are currently supported.')
  local size = math.abs(n)
  local slice = {}
  local count = 1
  for value in self:ritems() do
    table.insert(slice, value)
    if count == size then
      return slice
    end
    count = count + 1
  end
  return slice
end

return OrderedSet
