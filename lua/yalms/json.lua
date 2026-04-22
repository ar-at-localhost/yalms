local JSON = {}

---JSON Encode
---@param value unknown
---@return string
---@env vim+wezterm
function JSON.encode(value)
  local ok, wezterm = pcall(function()
    return require("wezterm")
  end)

  ---@cast wezterm Wezterm
  if ok and wezterm then
    return wezterm.json_encode(value)
  end

  return vim.json.encode(value)
end

---JSON Decode
---@param value string
---@return unknown
---@env vim+wezterm
function JSON.decode(value)
  local ok, wezterm = pcall(function()
    return require("wezterm")
  end)

  ---@cast wezterm Wezterm
  if ok and wezterm then
    return wezterm.json_parse(value)
  end

  return vim.json.decode(value)
end

return JSON
