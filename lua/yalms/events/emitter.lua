---@class EventEmitter
---@field _subscribers table<string, fun(payload: unknown)[]>
local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter:new()
  local instance = setmetatable({}, self)
  instance._subscribers = {}
  return instance
end

---@param event string
---@param callback fun(payload: unknown)
function EventEmitter:on(event, callback)
  self._subscribers[event] = self._subscribers[event] or {}
  table.insert(self._subscribers[event], callback)

  return self
end

---@param event string
---@param callback fun(payload: unknown)
function EventEmitter:off(event, callback)
  local index = self:_find(event, callback)
  if index then
    table.remove(self._subscribers[event], index)
  end

  return self
end

---@param event string
---@param callback fun(payload: unknown)
---@return boolean
function EventEmitter:has(event, callback)
  local index = self:_find(event, callback)
  return index ~= nil
end

---@protected
---@param event string
---@param callback fun(payload: unknown)
---@return integer?
function EventEmitter:_find(event, callback)
  for i, sub in ipairs(self._subscribers[event] or {}) do
    if sub == callback then
      return i
    end
  end
end

---@param event string
---@param payload unknown
function EventEmitter:emit(event, payload)
  for _, sub in ipairs(self._subscribers[event] or {}) do
    pcall(sub, event, payload)
  end

  return self
end

return EventEmitter
