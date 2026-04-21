---@class JsonUtils
---@field encode fun(arg: unknown): string
---@field decode fun(arg: string): unknown
---@class FsUtils
---@field json JsonUtils
local M = {} ---@type FsUtils

---@nvim @wezterm
M.json = {
  encode =
    ---JSON Encode
    ---@param value unknown
    ---@return string
    function(value)
      local ok, wezterm = pcall(function()
        return require("wezterm")
      end)

      ---@cast wezterm Wezterm
      if ok and wezterm then
        return wezterm.json_encode(value)
      end

      return vim.json.encode(value)
    end,

  decode =
    ---JSON Decode
    ---@param value string
    ---@return unknown
    function(value)
      local ok, wezterm = pcall(function()
        return require("wezterm")
      end)

      ---@cast wezterm Wezterm
      if ok and wezterm then
        return wezterm.json_parse(value)
      end

      return vim.json.decode(value)
    end,
}

--- Attempts to create a new file at the given path.
---@param path string The file path to create.
---@return boolean success True if the file was created successfully, false otherwise.
function M.attempt_create_file(path)
  local success, _ = pcall(function()
    local file = io.open(path, "w")
    if not file then
      error("Failed to create file: " .. path)
    end
    file:close()
  end)
  return success
end

--- Write plain string to file (overwrite).
---@param path string
---@param data string
---@return boolean success
---@return string|nil err
function M.write_file(path, data)
  local ok, err = pcall(function()
    local file = assert(io.open(path, "w"))
    file:write(data)
    file:close()
  end)
  return ok, ok and nil or err
end

--- Read plain string from file.
---@param path string
---@return string|nil content
---@return string|nil err
function M.read_file(path)
  local ok, result = pcall(function()
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
  end)
  if ok then
    return result, nil
  else
    return nil, result
  end
end

---@param path string
---@param default_tbl table
---@return table
function M.safe_read_json(path, default_tbl)
  local data = M.read_json(path)
  if data and type(data) == "table" then
    return data
  end
  M.write_json(path, default_tbl)
  return default_tbl
end

--- Write Lua table as JSON to file.
---@param path string
---@param tbl table
---@return boolean success
---@return string|nil err
function M.write_json(path, tbl)
  local ok, err = pcall(function()
    local json_str = M.json.encode(tbl)
    local file = assert(io.open(path, "w"))
    file:write(json_str)
    file:close()
  end)
  return ok, ok and nil or err
end

--- Read Lua table from JSON file.
---@param path string
---@return table|nil data
---@return string|nil err
function M.read_json(path)
  local content, read_err = M.read_file(path)
  if not content then
    return nil, read_err
  end

  local ok, result = pcall(function()
    return M.json.decode(content)
  end)

  if ok then
    return result, nil
  else
    return nil, result
  end
end

---Copy file
---@param src string
---@param dest string
function M.copy_file(src, dest)
  local in_file = assert(io.open(src, "rb"))
  local data = in_file:read("*a")
  in_file:close()

  local out_file = assert(io.open(dest, "wb"))
  out_file:write(data)
  out_file:close()
end

---Ensure file exists, creating it (and parent dirs) if not.
---If the file exists but is empty, writes content.
---@param path string
---@param recursive? boolean create parent directories if missing
---@param content? string initial content to write
---@return boolean success
---@return string|nil err
function M.touch(path, recursive, content)
  local f = io.open(path, "r")
  local data = f and f:read("*a")
  if f then
    f:close()
  end

  if data and data ~= "" then
    return true, nil
  end

  if not data and recursive then
    local dir = path:match("(.+)/[^/]+$")
    if dir then
      os.execute(string.format("mkdir -p %q", dir))
    end
  end

  local ok, err = pcall(function()
    local wf = assert(io.open(path, "w"))
    if content then
      wf:write(content)
    end
    wf:close()
  end)
  return ok, ok and nil or err
end

---Ensure directory exists, creating it (and parent dirs) if not. No-op if already present.
---@param path string
---@return boolean success
---@return string|nil err
function M.ensure_dir(path)
  local ok, err = pcall(function()
    os.execute(string.format("mkdir -p \"%s\"", path))
  end)
  return ok, ok and nil or err
end
return M
