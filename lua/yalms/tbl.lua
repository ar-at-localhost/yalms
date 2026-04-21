---@class TableUtils
---@field deep_copy fun(a: table, _seen?: table): table deep copy tables
---@field deep_equal fun(a: table, b: table, _seen: table?): boolean Check if 2 tables are deeply equal
---@field merge_all fun(...: table): table Merge multiple tables
---@field slice fun(arg: table, first: number, last?: number): table Slice a table
local M = {} ---@type TableUtils

function M.deep_equal(a, b, seen)
  if a == b then
    return true
  end
  if type(a) ~= type(b) or type(a) ~= "table" then
    return false
  end

  seen = seen or {}
  local key = tostring(a) .. "|" .. tostring(b)
  if seen[key] then
    return true
  end
  seen[key] = true

  for k, v in pairs(a) do
    if not M.deep_equal(v, b[k], seen) then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end

  return true
end

function M.merge_all(...)
  local result = {}
  for _, tbl in ipairs({ ... }) do
    if type(tbl) == "table" then
      for k, v in pairs(tbl) do
        result[k] = v
      end
    end
  end
  return result
end

function M.deep_copy(orig, seen)
  if type(orig) ~= "table" then
    return orig
  end

  seen = seen or {}
  if seen[orig] then
    return seen[orig]
  end

  local copy = {}
  seen[orig] = copy

  for k, v in pairs(orig) do
    copy[M.deep_copy(k, seen)] = M.deep_copy(v, seen)
  end

  return setmetatable(copy, getmetatable(orig))
end

function M.slice(arg, first, last)
  local sliced = {}
  first = first or 1
  last = last or #arg
  for i = first, last do
    sliced[#sliced + 1] = arg[i]
  end
  return sliced
end

function M.keys_to_num(t)
  if not t then
    error("Invalid table provided to keys_to_num")
  end

  local numeric = {}
  for k, v in pairs(t) do
    if k ~= nil then
      local num_key = tonumber(k)
      if num_key then
        numeric[num_key] = v
      else
        numeric[k] = v
      end
    end
  end

  return numeric
end

---Find an item in an array
---@generic T
---@param tbl T[]
---@param check fun(item: T): boolean
---@return T | nil, integer | nil
function M.find_one(tbl, check)
  for i, v in ipairs(tbl) do
    if check(v) then
      return v, i
    end
  end
end

---Filter in an array
---@generic T
---@param tbl T[]
---@param check fun(item: T): boolean
---@return T[]
function M.filter(tbl, check)
  local filtered = {}

  for _, item in ipairs(tbl) do
    if check(item) then
      table.insert(filtered, item)
    end
  end

  return filtered
end

---transform an array
---@generic T
---@generic U
---@param tbl T[]
---@param transform fun(item: T): string | number, U
---@return U[]
function M.map(tbl, transform)
  local mapped = {}

  for key, item in ipairs(tbl) do
    local k, i = transform(item)
    mapped[k or key] = i
  end

  return mapped
end

function M.deep_merge(...)
  local result = {}

  local function merge_into(target, src)
    for k, v in pairs(src) do
      if type(v) == "table" and type(target[k]) == "table" then
        merge_into(target[k], v)
      else
        target[k] = v
      end
    end
  end

  for _, tbl in ipairs({ ... }) do
    if type(tbl) == "table" then
      merge_into(result, tbl)
    end
  end

  return result
end

---Check if array contains all given elements
---@generic T
---@param tbl T[]
---@param ... T
---@return boolean
function M.arr_has(tbl, ...)
  for _, el in ipairs({ ... }) do
    local found = false
    for _, v in ipairs(tbl) do
      if v == el then
        found = true
        break
      end
    end
    if not found then
      return false
    end
  end
  return true
end

---Get unique values from an array (preserves order)
---@generic T
---@param tbl T[]
---@return T[]
function M.uniques(tbl)
  local seen = {}
  local result = {}

  for _, v in ipairs(tbl) do
    if not seen[v] then
      seen[v] = true
      result[#result + 1] = v
    end
  end

  return result
end

---@generic T
---@param value T | T[] | nil
---@return T[]
function M.ensure_array(value)
  if value == nil then
    return {}
  end

  if type(value) == "table" then
    return value
  end

  return { value }
end

---Generate a numeric sequence
---@param count integer number of elements
---@param start? integer default: 1
---@return integer[]
function M.seq(count, start)
  if type(count) ~= "number" then
    error("seq expects count as number")
  end

  if start == nil then
    start = 1
  elseif type(start) ~= "number" then
    error("seq expects start as number")
  end

  if count <= 0 then
    return {}
  end

  local result = {}

  for i = 0, count - 1 do
    result[#result + 1] = start + i
  end

  return result
end

return M
