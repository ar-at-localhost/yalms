local tbl = require("yalms.tbl")
local cr = require("yalms.cr.cr")

---@class YalmsCrExec
local CrExec = {}

---@class ExecBaseOpts :vim.SystemOpts
---@field do_not_clean? boolean -- Do not remove trailing newline
---@field throw? boolean

---@class ExecOpts :ExecBaseOpts
---@field cmd string|string[]

---@param overrides table
---@param base ExecBaseOpts
---@return ExecOpts
function CrExec.arg_merge(overrides, base)
	return vim.tbl_deep_extend("force", base, overrides) --[[@as ExecOpts]]
end

---@param arg ExecOpts
CrExec.exec = cr.async(function(arg, cb)
	local clone = tbl.deep_copy(arg)
	local cmd = type(clone.cmd) == "string" and { clone.cmd } or clone.cmd
	clone.cmd = nil

	vim.system(cmd, clone or {}, function(o)
		if o.code ~= 0 then
			if clone.throw then
				return error(o.stderr)
			end
			return cb(o.stderr)
		end

		-- Strip trailing newline from stdout
		local stdout = o.stdout:gsub("\n$", arg.do_not_clean and "\n" or "")
		cb(nil, stdout)
	end)
end)

return CrExec
