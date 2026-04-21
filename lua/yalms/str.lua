---@class StringUtils
---@field pad_right fun(str: string | nil, target_len: number, char?: string): string Pad string on the right to target length.
---@field pad_left fun(str: string | nil, target_len: number, char?: string): string Pad string on the left to target length.
---@field pad fun(str: string | nil, target_len: number, char?: string, ellipsis?: string): string Center pad string to target length. If string is longer than target_len, it will ellipsify.
---@field trim fun(str: string): string
local M = {} ---@type StringUtils

---@private
---@param char string
---@param n number
---@return string
local function repeat_char(char, n)
  if n <= 0 then
    return ""
  end
  return string.rep(char, n)
end

---@private
---@param char string|nil
---@return string
local function normalize_char(char)
  if not char or char == "" then
    return " "
  end
  return char:sub(1, 1)
end

---@param str string
---@param target_len number
---@param char? string Padding character (default: space)
---@return string
function M.pad_right(str, target_len, char)
  str = tostring(str or "")
  char = normalize_char(char)

  local len = #str
  if len >= target_len then
    return str
  end

  return str .. repeat_char(char, target_len - len)
end

---@param str string
---@param target_len number
---@param char? string Padding character (default: space)
---@return string
function M.pad_left(str, target_len, char)
  str = tostring(str or "")
  char = normalize_char(char)

  local len = #str
  if len >= target_len then
    return str
  end

  return repeat_char(char, target_len - len) .. str
end

---@param str string
---@param target_len number
---@param char? string Padding character (default: space)
---@param ellipsis? string Ellipsis string (default: "...")
---@return string
function M.pad(str, target_len, char, ellipsis)
  str = tostring(str or "")
  char = normalize_char(char)
  ellipsis = ellipsis or "..."

  local len = #str

  -- Oversized: ellipsify
  if len > target_len then
    if target_len <= #ellipsis then
      return ellipsis:sub(1, target_len)
    end

    local visible = target_len - #ellipsis
    return str:sub(1, visible) .. ellipsis
  end

  -- Exact
  if len == target_len then
    return str
  end

  -- Center pad
  local total_padding = target_len - len
  local left = math.floor(total_padding / 2)
  local right = total_padding - left

  return repeat_char(char, left) .. str .. repeat_char(char, right)
end

---Pad an array of string so that each item is uniformly padded
---@param items string[]
---@return table<string, string> paddd_items a dict width original string as key and padded string as value
---@return integer max_len maximum length applied
function M.pad_items(items)
  local padded = {}
  local max_len = 0

  for _, s in ipairs(items) do
    local len = s:len()
    if len > max_len then
      max_len = len
    end
  end

  for _, s in ipairs(items) do
    padded[s] = M.pad(s, max_len)
  end

  return padded, max_len
end

function M.trim(str)
  local trimmed = str:gsub("^%s*(.-)%s*$", "%1")
  return trimmed
end

---@param path string
function M.is_absolute_path(path)
  return path and path:sub(1, 1) == "/"
end

---@param str string
---@param sep string Separator (plain string, not pattern by default)
---@param opts? { plain?: boolean, trim?: boolean, skip_empty?: boolean }
---@return string[]
function M.split(str, sep, opts)
  opts = opts or {}
  local plain = opts.plain ~= false -- default true
  local trim = opts.trim or false
  local skip_empty = opts.skip_empty or false

  if sep == "" then
    -- split into characters
    local result = {}
    for i = 1, #str do
      table.insert(result, str:sub(i, i))
    end
    return result
  end

  local result = {}
  local start = 1

  while true do
    local i, j = string.find(str, sep, start, plain)
    if not i then
      local part = str:sub(start)
      if trim then
        part = M.trim(part)
      end
      if not (skip_empty and part == "") then
        table.insert(result, part)
      end
      break
    end

    local part = str:sub(start, i - 1)
    if trim then
      part = M.trim(part)
    end
    if not (skip_empty and part == "") then
      table.insert(result, part)
    end

    start = j + 1
  end

  return result
end

return M
