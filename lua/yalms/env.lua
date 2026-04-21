---@class EnvUtils
---@field ensure_nvim fun(desc?: string) Safely check for nvim environment
local M = {} ---@type EnvUtils

---@nvim
function M.ensure_nvim(desc)
  if type(vim) ~= "table" or type(vim.api) ~= "table" then
    error(string.format("%s: Neovim not detected!", desc or "Oops"), 2)
  end
end

---@nvim
function M.is_vim()
  return pcall(function()
    return type(vim) == "table" or type(vim.api) == "table"
  end)
end

---@wezterm
function M.is_wezterm()
  return pcall(function()
    return require("wezterm")
  end)
end

---Get environment variable
---@nvim @wezterm
---@param name string
function M.get_env(name)
  if M.is_vim() then
    return vim.fn.getenv(name)
  elseif M.is_wezterm() then
    return os.getenv(name)
  end
end
return M
