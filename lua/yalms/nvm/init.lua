---@class Global
---@field __nixvim_manager_nvim NixvimManager
G = G or {}
local M = {}

---@param opts? NixvimManagerOpts
function M.setup(opts)
  require("yamls.nvm.views").setup()
  local NixvimManager = require("yamls.nvm.manager")

  G.__nixvim_manager_nvim = NixvimManager:new(opts)
  return G.__nixvim_manager_nvim
end

function M.get()
  return G.__nixvim_manager_nvim
end

return M
