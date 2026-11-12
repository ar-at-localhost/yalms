local cr = require("yalms.cr.cr")
local exec = require("yalms.cr.exec")

---@class YalmsCrFS
local CrFS = {}

---@class readTextOpts :ExecBaseOpts
---@field path string
---@param opts readTextOpts
CrFS.read_text = function(opts)
	return exec.exec(exec.arg_merge(opts, { cmd = { "cat", opts.path }, text = true }))
end

---@class writeTextOpts :ExecBaseOpts
---@field path string
---@field text string
---@param opts writeTextOpts
CrFS.write_text = function(opts)
	return exec.exec(exec.arg_merge(opts, {
		cmd = {
			"sh",
			"-c",
			string.format("echo '%s' > %s", opts.text:gsub("'", "'\"'\"'"), opts.path),
		},

		text = true,
	}))
end

---@class mkdirOpts :ExecBaseOpts
---@field path string
---@field recursive? boolean
---@param opts mkdirOpts
CrFS.mkdir = function(opts)
	local cmd = { "mkdir", opts.path }
	if opts.recursive then
		table.insert(cmd, 2, "-p")
	end

	return exec.exec(exec.arg_merge(opts, {
		cmd = cmd,
		text = true,
	}))
end

---@class dirnameOpts :ExecBaseOpts
---@field path string
---@param opts dirnameOpts
CrFS.dirname = function(opts)
	return exec.exec(exec.arg_merge(opts, {
		cmd = { "dirname", opts.path },
		text = true,
	}))
end

---@class touchOpts :ExecBaseOpts
---@field path string
---@field create? boolean
---@param opts touchOpts
CrFS.touch = function(opts)
	return exec.exec(exec.arg_merge(opts, {
		cmd = { "touch", opts.path },
		text = true,
	}))
end

---@class rmOpts :ExecBaseOpts
---@field path string
---@field recursive? boolean
---@field force? boolean
---@param opts rmOpts
CrFS.rm = function(opts)
	return exec.exec(exec.arg_merge(opts, {
		cmd = { "rm", opts.recursive and "-r" or "", opts.force and "-f" or "", opts.path },
		text = true,
	}))
end

---@class existspts :ExecBaseOpts
---@field path string
---@param opts rmOpts
CrFS.exists = function(opts)
	return exec.exec(exec.arg_merge(opts, {
		cmd = { "stat", opts.path },
		text = true,
	}))
end

---@class touchOpts :ExecBaseOpts
---@param opts { path: string, text: string }
CrFS.ensure_file = function(opts)
	local ok, res = CrFS.dirname({ path = opts.path, throw = true })
	CrFS.mkdir({ path = res, recursive = true, throw = true })
	CrFS.touch({ path = opts.path, throw = true })

	if opts.text then
		ok, res = CrFS.read_text({ path = opts.path, throw = true })

		if res ~= opts.text then
			return CrFS.write_text(opts)
		end
	end

	return ok, res
end

return CrFS
