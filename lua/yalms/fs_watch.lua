local uv = vim.uv

---@snacks
---@generic T
---@param fn T
---@param opts? {ms?:number}
---@return T
local function debounce(fn, opts)
	local timer = assert(uv.new_timer())
	local ms = opts and opts.ms or 20
	return function()
		timer:start(ms, 0, vim.schedule_wrap(fn))
	end
end

---@class FsWatchOpts
---@field root string
---@field on_change  fun(path: string)
---@field recursive? boolean
---@field debounce_ms? integer default: 500

---@class FsWatch
---@field _root string
---@field _recursive boolean
---@field _on_change fun(path: string)
---@field _watchers table<string, uv.uv_fs_event_t>
---@field _debounce_ms? integer default: 500
---@field _dirs table<string, boolean>
local FsWatch = {}
FsWatch.__index = FsWatch

---@param self FsWatch
---@param opts FsWatchOpts
function FsWatch:new(opts)
	local instance = setmetatable({}, self)
	opts = opts or {}
	instance._root = opts.root
	instance._recursive = opts.recursive or false
	instance._on_change = opts.on_change or function() end
	instance._watchers = {}
	instance._dirs = {}
	instance._debounce_ms = opts.debounce_ms or 500
	return instance
end

function FsWatch:_create_watcher(dir)
	if self._watchers[dir] then
		return
	end

	local handle = uv.new_fs_event() --[[@as uv.uv_fs_event_t]]
	uv.fs_event_start(
		handle,
		dir,
		{ flags = {} },
		debounce(function(err, filename, _)
			if err then
				return
			end
			local path = filename and (dir .. "/" .. filename) or dir
			self._on_change(path)
		end, {
			ms = self._debounce_ms,
		})
	)

	self._watchers[dir] = handle
end

function FsWatch:_scan_dir(dir)
	local handle, _ = vim.loop.fs_opendir(dir)

	if not handle then
		return
	end

	while true do
		local entries = vim.loop.fs_readdir(handle)
		if not entries then
			break
		end
		for _, entry in ipairs(entries) do
			if entry.type == "directory" then
				local subdir = dir .. "/" .. entry.name
				self._dirs[subdir] = true
				if self._recursive then
					self:_create_watcher(subdir)
					self:_scan_dir(subdir)
				end
			end
		end
	end
	vim.loop.fs_closedir(handle)
end

function FsWatch:start()
	if not vim.loop.fs_stat(self._root) then
		return
	end

	self:_create_watcher(self._root)

	if self._recursive then
		self:_scan_dir(self._root)
	end
end

function FsWatch:stop()
	for dir, handle in pairs(self._watchers) do
		uv.fs_event_stop(handle)
		self._watchers[dir] = nil
	end
	self._dirs = {}
end

function FsWatch:restart()
	self:stop()
	self:start()
end

return FsWatch
