local tbl = require("yalms.tbl")
local cr = require("yalms.cr.cr")
local exec = require("yalms.cr.exec")
local fs = require("yalms.cr.fs")

---@class YalmsCr :YalmsCrBase,YalmsCrExec,YalmsCrFS
local Cr = tbl.merge_all(cr, exec, fs)

return Cr
