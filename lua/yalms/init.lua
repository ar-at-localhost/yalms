---@class Yalms
local Yalms = {
  env = require("yalms.env"),
  fs = require("yalms.fs"),
  json = require("yalms.json"),
  str = require("yalms.str"),
  tbl = require("yalms.tbl"),
  time = require("yalms.time"),
}

---@class YalmsOpts

---@param opts? YalmsOpts
function Yalms.setup(opts)
  vim.notify("Yalms has no Neovim plugins added yet!")
end

return Yalms
