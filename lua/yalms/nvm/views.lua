local M = {
  setup = function()
    local nixvim_picker = require("yalms.nvm.nixvim")
    Snacks.picker.sources["nixvim"] = nixvim_picker
  end,
}

return M
