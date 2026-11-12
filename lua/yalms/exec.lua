---@alias ExecState 'ready' | 'running' | 'finished' | 'failed' | 'aborted'

---@class ExecCommand
---@field name string
---@field exec string | string[]
---@field exec_fun? fun(cb: fun(stdout: string, stderr: string, code: integer))
---@field cwd? string
---@field desc? string

---@class ProcessCommandRuntime :ExecCommand
---@field state ExecState
---@field output? string
---@field exit_code? integer
---@field last_updated? integer

---@class Process
---@field queue ProcessCommandRuntime[]
---@field current? ProcessCommandRuntime
---@field last? ProcessCommandRuntime
---@field paused boolean
---@field running boolean
---@field _aborting boolean

local EventEmitter = require("yalms.events.emitter")

local Process = setmetatable({}, { __index = EventEmitter })
Process.__index = Process

---@return Process
function Process.new(self)
	local instance = setmetatable({}, self)
	instance._subscribers = {}
	---@cast instance Process
	instance.queue = {}
	instance.last = nil
	instance.current = nil
	instance.paused = false
	instance.running = false
	instance._aborting = false
	return instance
end

---@param cmd ProcessCommandRuntime
---@param cb fun(stdout: string, stderr: string, code: integer)
local function execute(cmd, cb)
	if cmd.exec_fun then
		cmd.exec_fun(cb)
		return
	end

	local argv
	if type(cmd.exec) == "table" then
		argv = cmd.exec
	else
		argv = { "sh", "-c", cmd.exec }
	end

	vim.system(argv, { text = true, cwd = cmd.cwd }, function(res)
		cb(res.stdout or "", res.stderr or "", res.code)
	end)
end

---@param commands ProcessCommandRuntime[]
function Process:set(commands)
	self.queue = vim.deepcopy(commands or {})
	self:emit("ready", self.queue)
end

function Process:start()
	self:run_next()
end

function Process:run_next()
	if self.paused then
		return
	end

	if self.running then
		return
	end

	local cmd = table.remove(self.queue, 1)
	if not cmd then
		self.current = nil
		self.running = false
		self:emit("done", self.last)
		return
	end

	self.current = cmd
	self.running = true

	cmd.state = "running"
	cmd.last_updated = os.time()
	self:emit("executing", cmd)

	execute(cmd, function(stdout, stderr, code)
		if self._aborting then
			cmd.state = "aborted"
			self:emit("error", { cmd = cmd, message = "aborted" })
		else
			cmd.output = stdout .. stderr
			cmd.exit_code = code
			cmd.state = (code == 0) and "finished" or "failed"
			cmd.last_updated = os.time()

			self.last = cmd

			if code ~= 0 then
				self:emit("error", { cmd = cmd, code = code })
			end

			self:emit("executed", cmd)
		end

		self.running = false
		self.current = nil

		vim.schedule(function()
			self:run_next()
		end)
	end)
end

function Process:pause()
	self.paused = true
end

function Process:resume()
	if not self.paused then
		return
	end

	self.paused = false
	self:run_next()
end

function Process:abort()
	if self.running then
		self._aborting = true
	end
	self.queue = {}
	self.paused = true
end

---@class YalmsExec
local YalmsExec = {
	Process = Process,
}

return YalmsExec
