---@class Yalms
local Yalms = {
  env = require("yalms.env"),
  fs = require("yalms.fs"),
  json = require("yalms.json"),
  str = require("yalms.str"),
  tbl = require("yalms.tbl"),
  time = require("yalms.time"),
  ui = require("yalms.ui"),
  nvm = require("yalms.nvm"),
}

---@class YalmsOpts
---@field nvm? NixvimManagerOpts

---@param opts? YalmsOpts
function Yalms.setup(opts)
  if not opts then
    return
  end

  if opts.nvm then
    require("yalms.nvm").setup(opts.nvm)
  end
end

return Yalms
