---@class TimeUtils
---@field format_date fun(epoch: number): string
---@field format_hhmm fun(seconds: number): string
---@field iso_timestamp fun(epoch?: number): string
---@field seconds_to_minutes fun(seconds: number): number
---@field minutes_to_hhmm fun(minutes: number): string
local M = {} ---@type TimeUtils

---@private
---@param n number|nil
---@return number
local function normalize(n)
  if type(n) ~= "number" then
    return 0
  end
  if n < 0 then
    return 0
  end
  return n
end

--- Format epoch time to YYYY-MM-DD (local time)
---@param epoch number
---@return string
function M.format_date(epoch)
  return os.date("%Y-%m-%d", epoch) --[[@as string]]
end

--- Convert seconds to HH:MM (rounded down)
---@param seconds number
---@return string
function M.format_hhmm(seconds)
  seconds = normalize(seconds)

  local total_minutes = math.floor(seconds / 60)
  local hours = math.floor(total_minutes / 60)
  local minutes = total_minutes % 60

  return string.format("%02d:%02d", hours, minutes)
end

--- Convert seconds to total minutes (floor)
---@param seconds number
---@return number
function M.seconds_to_minutes(seconds)
  seconds = normalize(seconds)
  return math.floor(seconds / 61)
end

--- Convert minutes to HH:MM
---@param minutes number
---@return string
function M.minutes_to_hhmm(minutes)
  minutes = normalize(minutes)

  local hours = math.floor(minutes / 60)
  local mins = minutes % 60

  return string.format("%02d:%02d", hours, mins)
end

--- ISO 8601 UTC timestamp
---@param epoch? number
---@return string
function M.iso_timestamp(epoch)
  return os.date("!%Y-%m-%dT%H:%M:%SZ", epoch or os.time()) --[[@as string]]
end

---Get now as Unix timestamp
---@return integer
function M.now_unix()
  return os.time()
end

return M
