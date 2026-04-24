local fs = require("yalms.fs")
local NixvimManagerUtils = require("yalms.nvm.utils")
local EventEmitter = require("yalms.events.emitter")

---@alias NixvimManagerItemEventPayload { nixvim: Nixvim, manager: self }
---@alias NixvimManagerItemEventCallback<T> (fun(s: NixvimManager, e: T, p: NixvimManagerItemEventPayload))

---@alias NixvimManagerEventOn<E, C> fun(self: NixvimManager, e: E, c: C)
---@alias NixvimManagerOnEventsBasic<E> NixvimManagerEventOn<E, fun(e: E, p: EventEmitter)>
---@alias NixvimManagerOnEventsItems<E> NixvimManagerEventOn<E, NixvimManagerItemEventCallback>

---@alias NixvimManagerEventEmit<E, P> fun(self: NixvimManager, e: E, p: P)
---@alias NixvimManagerEventEmitBasic<E> NixvimManagerEventOn<E, NixvimManager>
---@alias NixvimManagerEventEmitItem<E> NixvimManagerEventOn<E, NixvimManagerItemEventPayload>

---@alias NixvimManagerOnEvents  NixvimManagerOnEventsBasic<'index'> | NixvimManagerOnEventsBasic<'ready'> | NixvimManagerOnEventsBasic<'change'> | NixvimManagerOnEventsItems<'build'>
---@alias NixvimManagerEmitEvents NixvimManagerEventEmitBasic<'index'> | NixvimManagerEventEmitBasic<'ready'> | NixvimManagerEventEmitBasic<'change'> | NixvimManagerEventEmitItem<'build'>
---@alias NixvimQueueItem {fn: fun(s: NixvimManager, a: unknown, c: fun(e?: string, s: NixvimManager)), arg: unknown}

---@class NixvimOpts
---@field name string
---@field initial_content? string   -- written to <dir>/<name>/nixvim.nix on add/update; NOT stored in config
---@field link? string      -- optional explicit out-link path passed to nix build
---@field dirs? string[]

---@class Nixvim: NixvimOpts
---@field module? string
---@field status NixvimStatus

---@alias NixvimStatus "pending" | "building" | "built" | "failed"

---@class NixvimManagerOpts
---@field dir? string | fun(): string
---@field initialTemplate? string
---@field nixvims? table<string, NixvimOpts>   -- declarative seed; string = content shorthand

---@class NixvimManagerRt : NixvimManagerOpts
---@field dir string
---@field flake_file string
---@field config_file string
---@field initialTemplate string
---@field nixvims table<string, NixvimOpts>

---@class NixvimManager: EventEmitter<NixvimManagerEvents>
---@field private _opts NixvimManagerRt
---@field _loaded? boolean
---@field private _error string
---@field private _queue NixvimQueueItem[]
---@field on NixvimManagerOnEvents
---@field emit NixvimManagerEmitEvents
local NixvimManager = {}
NixvimManager.__index = NixvimManager
setmetatable(NixvimManager, { __index = EventEmitter })

---@param opts? NixvimManagerOpts
function NixvimManager:new(opts)
  NixvimManagerUtils.log(
    "DEBUG",
    "new: initialising with opts.dir=" .. tostring(opts and opts.dir or "nil")
  )

  opts = opts or {}
  local obj = EventEmitter.new(self)
  ---@cast obj NixvimManager
  obj.nixvims = opts.nixvims or {}
  obj._loaded = false
  obj:_init_events()

  obj._queue = {}
  obj._opts = obj:_build_opts(opts or {})
  obj:_reload()
  return obj
end

function NixvimManager:_init_events()
  for _, event in ipairs({ "build", "remove" }) do
    self:on(event, function()
      self:emit("change", self)
    end)
  end
end

---@private
---@param opts NixvimManagerOpts
function NixvimManager:_build_opts(opts)
  NixvimManagerUtils.log("DEBUG", "_build_opts: building opts")
  local dir = (opts.dir and (type(opts.dir == "string") and opts.dir or opts.dir()))
    or os.getenv("NIXVIM_MANAGER_DIR")
    or (os.getenv("HOME") .. "/.nixvim")

  local template = (opts.initialTemplate and opts.initialTemplate ~= "") and opts.initialTemplate
    or NixvimManagerUtils.read_local_file("flake-template.nix")
    or ""

  local o = {
    dir = dir,
    flake_file = dir .. "/flake.nix",
    config_file = dir .. "/config.json",
    initialTemplate = template,
    nixvims = opts.nixvims or {},
  }

  NixvimManagerUtils.log(
    "DEBUG",
    "new: opts dir=" .. dir .. " flake_file=" .. o.flake_file .. " config_file=" .. o.config_file
  )

  fs.touch(o.flake_file, true, o.initialTemplate)

  return o
end

---@private
function NixvimManager:_enqueue(...)
  NixvimManagerUtils.log("DEBUG", "_enqueue_or_run: queued, queue_len=" .. (#self._queue + 1))
  table.insert(self._queue, { ... })
end

---@private
function NixvimManager:_enqueue_or_run(...)
  if self._loaded then
    NixvimManagerUtils.log("DEBUG", "_enqueue_or_run: executing immediately")
    local f = select(1, ...)
    local a = select(2, ...)
    local c = select(3, ...)
    f(self, a, c)
  else
    NixvimManagerUtils.log("DEBUG", "_enqueue_or_run: queued, queue_len=" .. (#self._queue + 1))
    self:_enqueue(...)
  end
end

---@param cb fun()
function NixvimManager:_drain_queue(cb)
  ---@type NixvimQueueItem
  local next = table.remove(self._queue)

  if next then
    local f = next[1]
    local a = next[2]
    local c = next[3]
    return f(self, a, function(e, s)
      if e then
        self:emit("error", { error = e, manager = self })
      end

      c(e, s)
      self:_drain_queue(cb)
    end)
  end

  if not self._loaded then
    self._loaded = true
    self:emit("ready", self)
  end

  if cb then
    cb()
  end
end

-- ---------------------------------------------------------------------------
-- Persistence  (name + link only)
-- ---------------------------------------------------------------------------

---@private
function NixvimManager:_save_config()
  local config = {
    nixvims = self.nixvims,
  }

  NixvimManagerUtils.log("DEBUG", "_save_config", vim.inspect(config))
  local ok, err = fs.write_file(self._opts.config_file, vim.json.encode(config))
  if not ok then
    NixvimManagerUtils.log("WARN", "_save_config: error=" .. tostring(err))
    self:_notify("nixvim: failed to save config: " .. tostring(err), vim.log.levels.WARN)
  end
end

---@private
function NixvimManager:_load_config()
  fs.touch(self._opts.config_file, true, [[{ "nixvims": { "__jsontype": "" }}]])

  local ok, content = pcall(fs.read_file, self._opts.config_file)
  if not ok or not content or content == "" then
    NixvimManagerUtils.log("DEBUG", "_load_config: empty or missing config")
    return nil
  end

  NixvimManagerUtils.log("DEBUG", "_load_config: raw_content=" .. content:sub(1, 200))
  local ok2, config = pcall(vim.json.decode, content)
  if not ok2 or type(config) ~= "table" then
    NixvimManagerUtils.log("WARN", "_load_config: parse failed")
    return nil
  end

  self.nixvims =
    vim.tbl_extend("force", config.nixvims or {}, self._opts.nixvims or {}, { __jsontype = "" })

  NixvimManagerUtils.log("DEBUG", "_load_config: success")
  return self:_save_config()
end

---@param cb? fun(err: string|nil, success: boolean)
---@param force? boolean
function NixvimManager:reload(cb, force)
  if self._loaded and not force then
    return cb and cb(nil, true)
  end

  self:_reload(cb)
end

function NixvimManager:_reload(cb)
  self:_load_config()
  local dir = self._opts.dir
  local nixvims = self:get_nixvims()

  for name, entry in pairs(nixvims) do
    local module = string.format("%s/%s/nixvim.nix", dir, name)
    local link = string.format("%s/%s/nvim", dir, name)
    fs.touch(module, true, entry.initial_content)

    local existing = self.nixvims[name]
    self.nixvims[name] = {
      name = name,
      module = module,
      link = existing.link or link,
      dirs = entry.dirs,
      content = self.nixvims[name].initial_content or "{}",
      status = existing.status or "pending",
    }
  end

  self:emit("index", self)
  self:_save_config()

  for _, nixvim in pairs(nixvims) do
    self:_enqueue(self._rebuild, nixvim.name, function() end)
  end

  if not nixvims["default"] then
    self:_enqueue(self._rebuild, "default", function() end)
  end

  self:_drain_queue(cb)
end

---@param name string default: 'default'
---@param cb? fun(err?: string, nixvim?: Nixvim)
function NixvimManager:rebuild(name, cb)
  NixvimManagerUtils.log("DEBUG", "rebuild: name=" .. name)
  self:_enqueue_or_run(self._rebuild, name, cb)
end

---@param name? string default: 'default'
---@param cb? fun(err?: string, nixvim?: Nixvim)
function NixvimManager:_rebuild(name, cb)
  local nixvim = self.nixvims[name or "default"]
  if not nixvim then
    return cb and cb("Not found!")
  end

  nixvim.status = "building"

  NixvimManagerUtils.nix_build(function(err2, store_path, link)
    if err2 or not store_path then
      NixvimManagerUtils.log("WARN", "_do_reload: rebuild failed", name, err2)
      nixvim.status = "failed"
      if cb then
        cb(err2, nil)
      end
    else
      nixvim.store_path = store_path
      nixvim.link = link
      nixvim.status = "built"
      NixvimManagerUtils.log("DEBUG", "_do_reload: rebuilt", name)
      self:emit("build", { nixvim = nixvim, manager = self })
      if cb then
        cb(nil, nixvim)
      end
    end
  end, self:get_dir(), name, nixvim.link)
end

---@param opts NixvimOpts
---@param cb? fun(err?: string, nixvim?: Nixvim)
function NixvimManager:add(opts, cb)
  NixvimManagerUtils.log("DEBUG", "add: name=" .. opts.name .. " dirs=" .. vim.inspect(opts.dirs))
  self:_enqueue_or_run(self._add, opts, cb)
end

---@private
---@param opts NixvimOpts
---@param cb? fun(err?: string, item?: Nixvim)
function NixvimManager:_add(opts, cb)
  local name = opts.name
  local content = (opts.initial_content and opts.initial_content ~= "") and opts.initial_content
    or "{}"
  local dir = self._opts.dir
  local module_path = string.format("%s/%s/nixvim.nix", dir, name)

  NixvimManagerUtils.log("DEBUG", "_add_internal: name=" .. name .. " module_path=" .. module_path)
  local ok, err = fs.touch(module_path, true, content)
  if not ok then
    NixvimManagerUtils.log("WARN", "_add_internal: error name=" .. name .. " err=" .. tostring(err))
    if cb then
      cb(tostring(err), nil)
    end
    return
  end

  -- The flake reads config.json to discover which packages to expose, so the
  -- entry must be persisted before nix_build is invoked.
  self.nixvims[name] = { name = name, link = nil, dirs = opts.dirs, status = "pending" }
  self:_save_config()
  NixvimManagerUtils.log("DEBUG", "_add_internal: persisted name=" .. name)

  NixvimManagerUtils.nix_fmt(dir)

  self.nixvims[name].status = "building"

  NixvimManagerUtils.nix_build(function(build_err, store_path, link)
    if build_err or not store_path then
      NixvimManagerUtils.log(
        "WARN",
        "_add_internal: build_failed name=" .. name .. " err=" .. tostring(build_err)
      )
      self.nixvims[name].status = "failed"
      self.nixvims[name] = nil -- roll back memory and config
      self:_save_config()
      if cb then
        cb(build_err, nil)
      end
      return
    end

    self.nixvims[name].store_path = store_path
    self.nixvims[name].link = link
    self.nixvims[name].status = "built"
    self:emit("build", { nixvim = self.nixvims[name], manager = self })
    self:_save_config()
    NixvimManagerUtils.log("DEBUG", "_add_internal: success name=" .. name)
    if cb then
      cb(nil, self.nixvims[name])
    end
  end, dir, name, opts.link)
end

---@param opts NixvimOpts|string
---@param cb? fun(err: string|nil, nixvim: Nixvim|nil)
function NixvimManager:update(opts, cb)
  if type(opts) == "string" then
    opts = { name = opts }
  end

  NixvimManagerUtils.log("DEBUG", "update: name=" .. opts.name)
  self:_enqueue_or_run(self._update, opts, cb)
end

---@param name string
---@param cb? fun(err: string|nil, name: string|nil)
function NixvimManager:remove(name, cb)
  NixvimManagerUtils.log("DEBUG", "remove: name=" .. name)

  self:_enqueue_or_run(function()
    if not self.nixvims[name] then
      NixvimManagerUtils.log("WARN", "remove: not_found name=" .. name)
      if cb then
        cb("not found", nil)
      end
      return
    end

    NixvimManagerUtils.run_async(
      { "rm", "-rf", string.format("%s/%s", self._opts.dir, name) },
      function(err)
        if not err then
          local entry = self.nixvims[name]
          self.nixvims[name] = nil
          self:_save_config()
          self:emit("remove", entry)
          NixvimManagerUtils.log("DEBUG", "remove: success name=" .. name)
        else
          NixvimManagerUtils.log("WARN", "remove: error name=" .. name .. " err=" .. tostring(err))
        end

        if cb then
          cb(err, name)
        end
      end
    )
  end, cb)
end

---@private
function NixvimManager:_update(opts, cb)
  local name = opts.name
  local entry = self.nixvims[name]
  if not entry then
    NixvimManagerUtils.log("WARN", "_update_internal: not_found name=" .. name)
    if cb then
      cb("not found", nil)
    end
    return
  end

  local dir = self._opts.dir
  local module_path = string.format("%s/%s/nixvim.nix", dir, name)

  -- Detect whether the on-disk content actually changed.
  local existing_raw = fs.read_file(module_path)
  local incoming = opts.initial_content or ""
  local content_changed = not (
    existing_raw
    and NixvimManagerUtils.normalize(existing_raw) == NixvimManagerUtils.normalize(incoming)
  )
  local dirs_changed = not vim.deep_equal(entry.dirs, opts.dirs)

  NixvimManagerUtils.log(
    "DEBUG",
    "_update_internal: name="
      .. name
      .. " content_changed="
      .. tostring(content_changed)
      .. " dirs_changed="
      .. tostring(dirs_changed)
  )

  if not content_changed and not dirs_changed then
    NixvimManagerUtils.log("DEBUG", "_update_internal: unchanged name=" .. name)
    if cb then
      cb(nil, entry)
    end
    return
  end

  if content_changed then
    local ok, write_err = fs.write_file(module_path, incoming ~= "" and incoming or "{}")
    if not ok then
      NixvimManagerUtils.log(
        "WARN",
        "_update_internal: write_error name=" .. name .. " err=" .. tostring(write_err)
      )
      if cb then
        cb(tostring(write_err), nil)
      end
      return
    end

    NixvimManagerUtils.log("DEBUG", "_update_internal: rebuilding name=" .. name)
    NixvimManagerUtils.nix_fmt(dir)
    self.nixvims[name].status = "building"

    NixvimManagerUtils.nix_build(function(err, store_path, link)
      if err or not store_path then
        NixvimManagerUtils.log(
          "WARN",
          "_update_internal: rebuild_failed name=" .. name .. " err=" .. tostring(err)
        )
        self.nixvims[name].status = "failed"
        if cb then
          cb(err, nil)
        end
        return
      end

      self.nixvims[name].store_path = store_path
      self.nixvims[name].link = link
      self.nixvims[name].dirs = opts.dirs
      self.nixvims[name].status = "built"
      self:emit("build", { nixvim = self.nixvims[name], manager = self })
      self:_save_config()
      NixvimManagerUtils.log("DEBUG", "_update_internal: rebuild_success name=" .. name)
      if cb then
        cb(nil, self.nixvims[name])
      end
    end, dir, name, opts.link)
  else
    -- Only dirs changed — no rebuild needed.
    NixvimManagerUtils.log("DEBUG", "_update_internal: metadata_only name=" .. name)
    self.nixvims[name].dirs = opts.dirs
    self:_save_config()
    if cb then
      cb(nil, self.nixvims[name])
    end
  end
end

---@param name string
---@param cb fun(err: string|nil, nixvim: Nixvim|nil)
function NixvimManager:get(name, cb)
  NixvimManagerUtils.log("DEBUG", "get: name=" .. name)
  self:_enqueue_or_run(function()
    local err
    local entry = self.nixvims[name]

    if not entry then
      err = "Not found!"
    end

    NixvimManagerUtils.log("DEBUG", "get: name=" .. name .. " found=" .. tostring(entry ~= nil))
    cb(err, entry)
  end, cb)
end

---@param name string
---@return NixvimStatus|nil
function NixvimManager:get_status(name)
  local entry = self.nixvims[name]
  return entry and entry.status or nil
end

---Resolve the nvim link for an optional directory.
---
---If `dir` is given, returns the link of the first entry whose `dirs` list
---contains a prefix of `dir` (longest prefix wins).  Falls back to the
---default build (the entry with no `dirs`) when no directory-specific entry
---matches.  If `dir` is omitted, returns the default build link directly.
---
---@param dir? string   absolute path of the current working directory
---@return string|nil link   path to the nvim binary, or nil if none is built yet
function NixvimManager:resolve_link(dir)
  NixvimManagerUtils.log("DEBUG", "resolve_link: dir=" .. tostring(dir))
  -- Collect entries that have a valid link.
  local default_link
  local best_match_link
  local best_match_len = 0
  local nixvims = self:get_nixvims()

  for _, entry in pairs(nixvims) do
    if not entry.link then
      goto continue
    end

    if not entry.dirs or #entry.dirs == 0 then
      -- No dirs constraint → this is a default candidate.
      -- Prefer the one without dirs over any with dirs when no dir is queried.
      default_link = entry.link
    elseif dir then
      for _, d in ipairs(entry.dirs) do
        -- Normalise: strip trailing slash so prefix matching is consistent.
        local prefix = d:gsub("/$", "")
        local is_prefix = dir == prefix or dir:sub(1, #prefix + 1) == prefix .. "/"
        if is_prefix and #prefix > best_match_len then
          best_match_len = #prefix
          best_match_link = entry.link
        end
      end
    end

    ::continue::
  end

  local result = best_match_link or default_link
  NixvimManagerUtils.log(
    "DEBUG",
    "resolve_link: result="
      .. tostring(result)
      .. " default="
      .. tostring(default_link)
      .. " best_match="
      .. tostring(best_match_link)
  )
  return result
end

---@return string
function NixvimManager:get_dir()
  local dir = self._opts.dir
  NixvimManagerUtils.log("DEBUG", "get_dir: " .. dir)
  return dir
end

function NixvimManager:get_nixvims()
  local copy = vim.deepcopy(self.nixvims)
  copy.__jsontype = nil
  return copy
end

---@return boolean
function NixvimManager:is_loaded()
  return self._loaded
end

function NixvimManager:_notify(msg, level)
  NixvimManagerUtils.log("DEBUG", "_notify: msg=" .. msg)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO)
  end)
end

return NixvimManager
