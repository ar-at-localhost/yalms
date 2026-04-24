---@class Global
---@field __nixvim_manager_nvim NixvimManager
local M = {}

---@param opts? NixvimManagerOpts
function M.setup(opts)
  if _G.__nixvim_manager_nvim then
    return _G.__nixvim_manager_nvim
  end

  require("yalms.nvm.views").setup()
  local NixvimManager = require("yalms.nvm.manager")
  _G.__nixvim_manager_nvim = NixvimManager:new(opts)
  return _G.__nixvim_manager_nvim
end

function M.get()
  return _G.__nixvim_manager_nvim
end

return M
