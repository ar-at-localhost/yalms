local fs = require("yalms.fs")

local GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
local DEBUG = os.getenv("DEBUG")

local function log(level, ...)
  if DEBUG then
    local msg = ""
    for i = 1, select("#", ...) do
      msg = msg .. " " .. tostring(select(i, ...))
    end
    vim.schedule(function()
      vim.print(string.format("[NixvimManager](%s) %s", level, msg))
    end)
  end
end

local function nix_access_tokens()
  local has_token = GITHUB_TOKEN ~= nil
  log("DEBUG", "nix_access_tokens: token_present=" .. tostring(has_token))
  if not GITHUB_TOKEN then
    return nil
  end
  return string.format("github.com=%s", GITHUB_TOKEN)
end

local function read_local_file(name)
  local src = debug.getinfo(1, "S").source
  log("DEBUG", "read_local_file: name=" .. name .. " source=" .. tostring(src))
  if src:sub(1, 1) == "@" then
    local dir = src:sub(2):match("(.+)/[^/]+$")
    if dir then
      local f = io.open(dir .. "/" .. name, "r")
      if f then
        local content = f:read("*a")
        f:close()
        log("DEBUG", "read_local_file: success name=" .. name)
        return content
      end
    end
  end
  log("DEBUG", "read_local_file: not_found name=" .. name)
end

---Format the entire flake (best-effort, non-fatal).
---@param flake_dir string
local function nix_fmt(flake_dir)
  local cmd = { "nix", "fmt" }

  local tokens = nix_access_tokens()
  if tokens then
    table.insert(cmd, "--option")
    table.insert(cmd, "access-tokens")
    table.insert(cmd, tokens)
  end

  log("DEBUG", "nix_fmt: flake_dir=" .. flake_dir .. " cmd=" .. vim.inspect(cmd))
  vim.system(cmd, { text = true, cwd = flake_dir }, function(r)
    log("DEBUG", "nix_fmt: flake_dir=" .. flake_dir .. " exit_code=" .. r.code)
  end)
end

---@param cmd string[]
---@param cb fun(err: string|nil, stdout: string|nil)
local function run_async(cmd, cb)
  log("DEBUG", "run_async: cmd=" .. vim.inspect(cmd))
  vim.system(cmd, { text = true }, function(r)
    if r.code ~= 0 then
      local err_msg = r.stderr ~= "" and r.stderr or r.stdout
      log("WARN", "run_async: error cmd=" .. vim.inspect(cmd) .. " err=" .. err_msg)
      cb(err_msg, nil)
    else
      log("DEBUG", "run_async: success cmd=" .. vim.inspect(cmd))
      cb(nil, r.stdout or "")
    end
  end)
end

---@param flake_dir string
---@param attr string
---@param out_link string|nil   -- nil = no --out-link
---@param cb fun(err: string|nil, store_path: string|nil)
local function nix_build(flake_dir, attr, out_link, cb)
  local cmd = {
    "nix",
    "build",
    string.format("%s#\"%s\"", flake_dir, attr),
    "--print-out-paths",
  }

  if out_link and out_link ~= "" then
    vim.list_extend(cmd, { "--out-link", out_link })
  end

  local tokens = nix_access_tokens()
  if tokens then
    table.insert(cmd, "--option")
    table.insert(cmd, "access-tokens")
    table.insert(cmd, tokens)
  end

  log(
    "DEBUG",
    "nix_build: flake_dir="
      .. flake_dir
      .. " attr="
      .. attr
      .. " out_link="
      .. tostring(out_link)
      .. " cmd="
      .. vim.inspect(cmd)
  )
  vim.system(cmd, { text = true, cwd = flake_dir }, function(r)
    if r.code ~= 0 then
      local err_msg = r.stderr ~= "" and r.stderr or r.stdout
      log(
        "WARN",
        "nix_build: error flake_dir=" .. flake_dir .. " attr=" .. attr .. " err=" .. err_msg
      )
      cb(err_msg, nil)
      return
    end
    local path = (r.stdout or ""):match("^%s*(/[%S]+)%s*$")
    if path then
      log(
        "DEBUG",
        "nix_build: success flake_dir=" .. flake_dir .. " attr=" .. attr .. " store_path=" .. path
      )
      cb(nil, path)
    else
      local err_msg = "unexpected nix build output: " .. tostring(r.stdout)
      log(
        "WARN",
        "nix_build: error flake_dir=" .. flake_dir .. " attr=" .. attr .. " err=" .. err_msg
      )
      cb(err_msg, nil)
    end
  end)
end

local function normalize(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@class NixvimOpts
---@field name string
---@field initial_content? string   -- written to <dir>/<name>/nixvim.nix on add/update; NOT stored in config
---@field link? string      -- optional explicit out-link path passed to nix build
---@field dirs? string[]
---@field base? string     -- which base to extend from; defaults to "default"

---@class Nixvim   -- in-memory + JSON representation
---@field name string
---@field link string|nil   -- resolved store path / symlink
---@field dirs string[]|nil -- directories this config applies to; nil = default/fallback
---@field base string|nil   -- which base to extend from; nil = "default"

---@class NixvimManagerOpts
---@field dir? string
---@field initialTemplate? string
---@field bases? table<string, string>  -- declarative seed; name -> nix content
---@field nixvim? table<string, NixvimOpts>   -- declarative seed; string = content shorthand
---@field on_ready? fun(err: string|nil, self: NixvimManager)

---@class NixvimManagerRt : NixvimManagerOpts
---@field dir string
---@field flake_file string
---@field config_file string
---@field initialTemplate string
---@field on_ready fun(err: string|nil, self: NixvimManager)
---@field bases table<string, string>
---@field nixvim table<string, NixvimOpts>

---@class NixvimManager
---@field nixvim table<string, Nixvim>
---@field bases table<string, string>
---@field private _opts NixvimManagerRt
---@field private _error string
---@field private _ready boolean
---@field private _queue { fn: fun() }[]
local NixvimManager = {}
NixvimManager.__index = NixvimManager

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

---@param opts? NixvimManagerOpts
function NixvimManager:new(opts)
  log("DEBUG", "new: initialising with opts.dir=" .. tostring(opts and opts.dir or "nil"))
  local o = setmetatable({}, self)
  o.bases = {}
  o.nixvim = {}
  o._ready = false

  o._queue = {}
  o._opts = o:_build_opts(opts or {})

  log("DEBUG", "new: starting reload")
  o:_do_reload(function(err)
    if err then
      log("WARN", "new: reload error=" .. err)
      ---@diagnostic disable-next-line: invisible
      o:_finalize_init(err)
      return
    end
    log("DEBUG", "new: sync declared")
    ---@diagnostic disable-next-line: invisible
    o:_sync_declared(function()
      ---@diagnostic disable-next-line: invisible
      o:_finalize_init(nil)
    end)
  end)

  return o
end

---@private
function NixvimManager:_build_opts(opts)
  log("DEBUG", "_build_opts: building opts")
  local dir = opts.dir or os.getenv("NIXVIM_MANAGER_DIR") or (os.getenv("HOME") .. "/.nixvim")

  local template = (opts.initialTemplate and opts.initialTemplate ~= "") and opts.initialTemplate
    or read_local_file("flake-template.nix")
    or ""

  local o = {
    dir = dir,
    flake_file = dir .. "/flake.nix",
    config_file = dir .. "/config.json",
    initialTemplate = template,
    on_ready = opts.on_ready or function() end,
    bases = opts.bases or {},
    nixvim = opts.nixvim or {},
  }

  log(
    "DEBUG",
    "new: opts dir=" .. dir .. " flake_file=" .. o.flake_file .. " config_file=" .. o.config_file
  )

  fs.touch(o.flake_file, true, o.initialTemplate)
  fs.touch(o.config_file, true, "{}") -- only creates when missing

  return o
end

-- ---------------------------------------------------------------------------
-- Init helpers
-- ---------------------------------------------------------------------------

---@private
function NixvimManager:_finalize_init(err)
  log("DEBUG", "_finalize_init: err=" .. tostring(err))
  self._error = err
  self._ready = true
  self._opts.on_ready(err, self)
  local queue = self._queue
  self._queue = {}
  log("DEBUG", "_finalize_init: executing queue, count=" .. #queue)
  for _, item in ipairs(queue) do
    item.fn()
  end
end

---@private
function NixvimManager:_enqueue_or_run(fn)
  if self._ready then
    log("DEBUG", "_enqueue_or_run: executing immediately")
    fn()
  else
    log("DEBUG", "_enqueue_or_run: queued, queue_len=" .. (#self._queue + 1))
    table.insert(self._queue, { fn = fn })
  end
end

-- ---------------------------------------------------------------------------
-- Persistence  (name + link only)
-- ---------------------------------------------------------------------------

---@private
function NixvimManager:_save_config()
  -- Save bases as array of keys (preserving order isn't critical for functionality)
  local bases_array = {}
  if self.bases then
    for name, _ in pairs(self.bases) do
      table.insert(bases_array, name)
    end
  end

  -- Save nixvims as dict
  local nixvims_out = {}
  local has_nixvims = false
  if self.nixvim then
    for name, entry in pairs(self.nixvim) do
      nixvims_out[name] = { name = name, link = entry.link, dirs = entry.dirs, base = entry.base }
      has_nixvims = true
    end
  end

  local config = {
    bases = bases_array,
    nixvims = has_nixvims and nixvims_out or setmetatable({}, { __jsontype = "object" }),
  }

  log(
    "DEBUG",
    "_save_config: bases_count="
      .. #bases_array
      .. " nixvims_count="
      .. (has_nixvims and vim.tbl_count(nixvims_out) or 0)
  )
  local ok, err = fs.write_file(self._opts.config_file, vim.json.encode(config))
  if not ok then
    log("WARN", "_save_config: error=" .. tostring(err))
    self:_notify("nixvim: failed to save config: " .. tostring(err), vim.log.levels.WARN)
  end
end

---@private
function NixvimManager:_save_base(name, content)
  log("DEBUG", "_save_base: name=" .. name)
  local base_file = self._opts.dir .. "/_" .. name .. ".nix"
  local ok, err = fs.write_file(base_file, content)
  if not ok then
    log("WARN", "_save_base: error name=" .. name .. " err=" .. tostring(err))
    self:_notify(
      "nixvim: failed to save base '" .. name .. "': " .. tostring(err),
      vim.log.levels.WARN
    )
  end
  return ok, err
end

function NixvimManager:add_base(opts, cb)
  log("DEBUG", "add_base: name=" .. opts.name)
  self:_enqueue_or_run(function()
    self:_add_base_internal(opts, cb)
  end)
end

---@param opts {name: string, content: string}
---@param cb? fun(err: string|nil)
function NixvimManager:update_base(opts, cb)
  log("DEBUG", "update_base: name=" .. opts.name)
  self:_enqueue_or_run(function()
    self:_update_base_internal(opts, cb)
  end)
end

---@param name string
---@param cb? fun(err: string|nil)
function NixvimManager:remove_base(name, cb)
  log("DEBUG", "remove_base: name=" .. name)
  self:_enqueue_or_run(function()
    if not self.bases[name] then
      log("WARN", "remove_base: not_found name=" .. name)
      if cb then
        cb("base not found: " .. name)
      end
      return
    end

    local base_file = self._opts.dir .. "/_" .. name .. ".nix"
    run_async({ "rm", "-f", base_file }, function(err)
      if not err then
        self.bases[name] = nil
        self:_save_config()
        log("DEBUG", "remove_base: success name=" .. name)
      else
        log("WARN", "remove_base: error name=" .. name .. " err=" .. tostring(err))
      end
      if cb then
        cb(err)
      end
    end)
  end)
end

---@param cb? fun(err: string|nil, bases: string[])
function NixvimManager:list_bases(cb)
  self:_enqueue_or_run(function()
    local base_names = {}
    for name, _ in pairs(self.bases) do
      table.insert(base_names, name)
    end
    table.sort(base_names) -- consistent ordering
    log("DEBUG", "list_bases: count=" .. #base_names)
    if cb then
      cb(nil, base_names)
    end
  end)
end

---@private
function NixvimManager:_add_base_internal(opts, cb)
  local name = opts.name
  local content = opts.content

  log("DEBUG", "_add_base_internal: name=" .. name)
  -- Validate name (must be filename-safe)
  if name:match("[/\\]") then
    log("WARN", "_add_base_internal: invalid name=" .. name .. " err=path separators")
    if cb then
      cb("base name cannot contain path separators: " .. name)
    end
    return
  end

  local base_file = self._opts.dir .. "/_" .. name .. ".nix"

  -- Check if already exists
  if self.bases[name] then
    log("WARN", "_add_base_internal: already_exists name=" .. name)
    if cb then
      cb("base already exists: " .. name)
    end
    return
  end

  local ok, write_err = fs.write_file(base_file, content)
  if not ok then
    log("WARN", "_add_base_internal: error name=" .. name .. " err=" .. tostring(write_err))
    if cb then
      cb(tostring(write_err), nil)
    end
    return
  end

  self.bases[name] = content
  self:_save_config()
  log("DEBUG", "_add_base_internal: success name=" .. name)

  if cb then
    cb(nil)
  end
end

---@private
function NixvimManager:_update_base_internal(opts, cb)
  local name = opts.name
  local content = opts.content

  log("DEBUG", "_update_base_internal: name=" .. name)
  -- Validate name
  if name:match("[/\\]") then
    log("WARN", "_update_base_internal: invalid name=" .. name .. " err=path separators")
    if cb then
      cb("base name cannot contain path separators: " .. name)
    end
    return
  end

  local base_file = self._opts.dir .. "/_" .. name .. ".nix"

  -- Check if exists
  if not self.bases[name] then
    log("WARN", "_update_base_internal: not_found name=" .. name)
    if cb then
      cb("base not found: " .. name)
    end
    return
  end

  -- Detect if content actually changed
  local existing_content = self.bases[name]
  if existing_content == content then
    log("DEBUG", "_update_base_internal: unchanged name=" .. name)
    if cb then
      cb(nil)
    end
    return
  end

  local ok, write_err = fs.write_file(base_file, content)
  if not ok then
    log("WARN", "_update_base_internal: error name=" .. name .. " err=" .. tostring(write_err))
    if cb then
      cb(tostring(write_err), nil)
    end
    return
  end

  self.bases[name] = content
  self:_save_config()
  log("DEBUG", "_update_base_internal: success name=" .. name)

  if cb then
    cb(nil)
  end
end

---@private
---@return {bases: string[], nixvims: table<string, Nixvim>}|nil
function NixvimManager:_load_config()
  local ok, content = pcall(fs.read_file, self._opts.config_file)
  if not ok or not content or content == "" then
    log("DEBUG", "_load_config: empty or missing config")
    return nil
  end

  log("DEBUG", "_load_config: raw_content=" .. content:sub(1, 200))
  local ok2, config = pcall(vim.json.decode, content)
  if not ok2 or type(config) ~= "table" then
    log("WARN", "_load_config: parse failed")
    return nil
  end

  -- Validate structure
  if type(config.bases) ~= "table" or type(config.nixvims) ~= "table" then
    log("WARN", "_load_config: invalid structure")
    return nil
  end

  -- Convert bases array to set for easier lookup
  local bases_set = {}
  for _, base_name in ipairs(config.bases) do
    if type(base_name) == "string" then
      bases_set[base_name] = true
    end
  end

  log(
    "DEBUG",
    "_load_config: bases_count="
      .. #config.bases
      .. " nixvims_count="
      .. vim.tbl_count(config.nixvims)
  )
  return {
    bases = config.bases, -- keep as array for persistence
    _bases_set = bases_set, -- for quick lookup
    nixvims = config.nixvims,
  }
end

-- ---------------------------------------------------------------------------
-- Reload  (cold start — no cache)
-- ---------------------------------------------------------------------------

---@param cb? fun(err: string|nil)
function NixvimManager:reload(cb)
  log("DEBUG", "reload: triggered")
  self:_enqueue_or_run(function()
    self:_do_reload(cb)
  end)
end

---@private
function NixvimManager:_do_reload(cb)
  log("DEBUG", "_do_reload: starting")
  local ok, err = pcall(function()
    local cached = self:_load_config()
    if not cached then
      log("DEBUG", "_do_reload: no cached config")
      if cb then
        cb(nil)
      end
      return
    end

    -- Load bases
    self.bases = {}
    local bases_loaded = 0
    if cached.bases then
      for _, base_name in ipairs(cached.bases) do
        if type(base_name) == "string" then
          local base_file = self._opts.dir .. "/_" .. base_name .. ".nix"
          local content = fs.read_file(base_file)
          if content then
            self.bases[base_name] = content
            bases_loaded = bases_loaded + 1
          end
        end
      end
    end
    log("DEBUG", "_do_reload: bases_loaded=" .. bases_loaded)

    -- Load nixvims
    self.nixvim = {}
    local nixvims_loaded = 0
    if cached.nixvims then
      for name, entry in pairs(cached.nixvims) do
        self.nixvim[name] = {
          name = entry.name,
          link = entry.link,
          dirs = entry.dirs,
          base = entry.base or "default",
        }
        nixvims_loaded = nixvims_loaded + 1
      end
    end
    log("DEBUG", "_do_reload: nixvims_loaded=" .. nixvims_loaded)

    -- Rebuild any entries that were persisted without a link.
    local dir = self._opts.dir
    local pending = {}
    for name, entry in pairs(self.nixvim) do
      if not entry.link then
        table.insert(pending, name)
      end
    end

    if #pending == 0 then
      log("DEBUG", "_do_reload: no rebuilds needed")
      if cb then
        cb(nil)
      end
      return
    end

    log("DEBUG", "_do_reload: rebuilding pending_count=" .. #pending)
    local remaining = #pending
    for _, name in ipairs(pending) do
      nix_build(dir, name, nil, function(_, store_path)
        if store_path then
          self.nixvim[name].link = store_path .. "/bin/nvim"
          log(
            "DEBUG",
            "_do_reload: rebuild_success name=" .. name .. " link=" .. self.nixvim[name].link
          )
        else
          log("WARN", "_do_reload: rebuild_failed name=" .. name)
        end
        remaining = remaining - 1
        if remaining == 0 then
          self:_save_config()
          log("DEBUG", "_do_reload: rebuilds_complete")
          if cb then
            cb(nil)
          end
        end
      end)
    end
  end)

  if not ok then
    log("WARN", "_do_reload: error=" .. tostring(err))
    cb(err)
  end
end

-- ---------------------------------------------------------------------------
-- Sync declared (called once during init, after _do_reload)
-- ---------------------------------------------------------------------------

---@private
function NixvimManager:_sync_declared(cb)
  log("DEBUG", "_sync_declared: starting")
  -- First sync bases
  local declared_bases = self._opts.bases
  local base_entries = {}
  if next(declared_bases) then
    for name, content in pairs(declared_bases) do
      table.insert(base_entries, { name = name, content = content })
    end
  end
  log("DEBUG", "_sync_declared: base_entries_count=" .. #base_entries)

  if #base_entries > 0 then
    local base_remaining = #base_entries
    local function base_done()
      base_remaining = base_remaining - 1
      log("DEBUG", "_sync_declared: base_done remaining=" .. base_remaining)
      if base_remaining == 0 then
        -- Now sync nixvims
        self:_sync_declared_nixvims(cb)
      end
    end

    for _, entry in ipairs(base_entries) do
      if self.bases[entry.name] then
        -- Update existing base
        self:_update_base_internal(entry, base_done)
      else
        -- Add new base
        self:_add_base_internal(entry, base_done)
      end
    end
  else
    -- No bases declared, sync nixvims directly
    log("DEBUG", "_sync_declared: no base_entries, syncing nixvims")
    self:_sync_declared_nixvims(cb)
  end
end

---@private
function NixvimManager:_sync_declared_nixvims(cb)
  local declared = self._opts.nixvim
  if not next(declared) then
    log("DEBUG", "_sync_declared_nixvims: no declared nixvims")
    cb()
    return
  end

  local entries = {}
  for name, v in pairs(declared) do
    local entry = type(v) == "string" and { name = name, initial_content = v }
      or vim.tbl_extend("force", v, { name = name })
    table.insert(entries, entry)
  end
  log("DEBUG", "_sync_declared_nixvims: entries_count=" .. #entries)

  local remaining = #entries
  local function done()
    remaining = remaining - 1
    log("DEBUG", "_sync_declared_nixvims: done remaining=" .. remaining)
    if remaining == 0 then
      cb()
    end
  end

  for _, entry in ipairs(entries) do
    if self.nixvim[entry.name] then
      self:_update_internal(entry, done)
    else
      self:_add_internal(entry, done)
    end
  end
end

---@private
function NixvimManager:_sync_declared_nixvims(cb)
  local declared = self._opts.nixvim
  if not next(declared) then
    log("DEBUG", "_sync_declared_nixvims: no declared nixvims")
    cb()
    return
  end

  local entries = {}
  for name, v in pairs(declared) do
    local entry = type(v) == "string" and { name = name, initial_content = v }
      or vim.tbl_extend("force", v, { name = name })
    table.insert(entries, entry)
  end
  log("DEBUG", "_sync_declared_nixvims: entries_count=" .. #entries)

  local remaining = #entries
  local function done()
    remaining = remaining - 1
    log("DEBUG", "_sync_declared_nixvims: done remaining=" .. remaining)
    if remaining == 0 then
      cb()
    end
  end

  for _, entry in ipairs(entries) do
    if self.nixvim[entry.name] then
      self:_update_internal(entry, done)
    else
      self:_add_internal(entry, done)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---@param opts NixvimOpts
---@param cb? fun(err?: string, nixvim?: Nixvim)
function NixvimManager:add(opts, cb)
  log(
    "DEBUG",
    "add: name="
      .. opts.name
      .. " base="
      .. tostring(opts.base)
      .. " dirs="
      .. vim.inspect(opts.dirs)
  )

  self:_enqueue_or_run(function()
    self:_add_internal(opts, cb)
  end)
end

---@param opts NixvimOpts|string
---@param cb? fun(err: string|nil, nixvim: Nixvim|nil)
function NixvimManager:update(opts, cb)
  if type(opts) == "string" then
    opts = { name = opts }
  end
  log("DEBUG", "update: name=" .. opts.name)
  self:_enqueue_or_run(function()
    self:_update_internal(opts, cb)
  end)
end

---@param name string
---@param cb? fun(err: string|nil)
function NixvimManager:remove(name, cb)
  log("DEBUG", "remove: name=" .. name)
  self:_enqueue_or_run(function()
    if not self.nixvim[name] then
      log("WARN", "remove: not_found name=" .. name)
      if cb then
        cb("not found")
      end
      return
    end

    run_async({ "rm", "-rf", string.format("%s/%s", self._opts.dir, name) }, function(err)
      if not err then
        self.nixvim[name] = nil
        self:_save_config()
        log("DEBUG", "remove: success name=" .. name)
      else
        log("WARN", "remove: error name=" .. name .. " err=" .. tostring(err))
      end
      if cb then
        cb(err)
      end
    end)
  end)
end

---@param name string
---@param cb fun(err: string|nil, nixvim: Nixvim|nil)
function NixvimManager:get(name, cb)
  log("DEBUG", "get: name=" .. name)
  self:_enqueue_or_run(function()
    local entry = self.nixvim[name]
    log("DEBUG", "get: name=" .. name .. " found=" .. tostring(entry ~= nil))
    cb(entry and nil or "not found", entry)
  end)
end

-- ---------------------------------------------------------------------------
-- Internal add / update
-- ---------------------------------------------------------------------------

---@private
---@param opts NixvimOpts
---@param cb? fun(err?: string, item?: Nixvim)
function NixvimManager:_add_internal(opts, cb)
  local name = opts.name
  local content = (opts.initial_content and opts.initial_content ~= "") and opts.initial_content
    or "{}"
  local dir = self._opts.dir
  local module_path = string.format("%s/%s/nixvim.nix", dir, name)

  log("DEBUG", "_add_internal: name=" .. name .. " module_path=" .. module_path)
  local ok, err = fs.touch(module_path, true, content)
  if not ok then
    log("WARN", "_add_internal: error name=" .. name .. " err=" .. tostring(err))
    if cb then
      cb(tostring(err), nil)
    end
    return
  end

  -- The flake reads config.json to discover which packages to expose, so the
  -- entry must be persisted before nix_build is invoked.
  self.nixvim[name] = { name = name, link = nil, dirs = opts.dirs, base = opts.base or "default" }
  self:_save_config()
  log("DEBUG", "_add_internal: persisted name=" .. name)

  nix_fmt(dir)

  nix_build(dir, name, opts.link, function(build_err, store_path)
    if build_err or not store_path then
      log("WARN", "_add_internal: build_failed name=" .. name .. " err=" .. tostring(build_err))
      self.nixvim[name] = nil -- roll back memory and config
      self:_save_config()
      if cb then
        cb(build_err, nil)
      end
      return
    end

    local link = (opts.link and opts.link ~= "") and opts.link or (store_path .. "/bin/nvim")
    self.nixvim[name].link = link
    self:_save_config()
    log("DEBUG", "_add_internal: success name=" .. name .. " link=" .. link)
    if cb then
      cb(nil, self.nixvim[name])
    end
  end)
end

---@private
function NixvimManager:_update_internal(opts, cb)
  local name = opts.name
  local entry = self.nixvim[name]
  if not entry then
    log("WARN", "_update_internal: not_found name=" .. name)
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
  local content_changed = not (existing_raw and normalize(existing_raw) == normalize(incoming))
  local dirs_changed = not vim.deep_equal(entry.dirs, opts.dirs)
  local base_changed = (opts.base or "default") ~= (entry.base or "default")

  log(
    "DEBUG",
    "_update_internal: name="
      .. name
      .. " content_changed="
      .. tostring(content_changed)
      .. " dirs_changed="
      .. tostring(dirs_changed)
      .. " base_changed="
      .. tostring(base_changed)
  )

  if not content_changed and not dirs_changed and not base_changed then
    log("DEBUG", "_update_internal: unchanged name=" .. name)
    if cb then
      cb(nil, entry)
    end
    return
  end

  if content_changed then
    local ok, write_err = fs.write_file(module_path, incoming ~= "" and incoming or "{}")
    if not ok then
      log("WARN", "_update_internal: write_error name=" .. name .. " err=" .. tostring(write_err))
      if cb then
        cb(tostring(write_err), nil)
      end
      return
    end

    -- Rebuild required; hold the old link in memory until the build succeeds.
    local old_link = entry.link
    log("DEBUG", "_update_internal: rebuilding name=" .. name)
    nix_fmt(dir)
    nix_build(dir, name, opts.link, function(err, store_path)
      if err or not store_path then
        -- Restore old link — config on disk is still valid from last save.
        self.nixvim[name].link = old_link
        log("WARN", "_update_internal: rebuild_failed name=" .. name .. " err=" .. tostring(err))
        if cb then
          cb(err, nil)
        end
        return
      end

      local link = (opts.link and opts.link ~= "") and opts.link or (store_path .. "/bin/nvim")
      self.nixvim[name].link = link
      self.nixvim[name].dirs = opts.dirs
      self.nixvim[name].base = opts.base or "default"
      self:_save_config()
      log("DEBUG", "_update_internal: rebuild_success name=" .. name .. " link=" .. link)
      if cb then
        cb(nil, self.nixvim[name])
      end
    end)
  else
    -- Only dirs or base changed — no rebuild needed.
    log("DEBUG", "_update_internal: metadata_only name=" .. name)
    self.nixvim[name].dirs = opts.dirs
    self.nixvim[name].base = opts.base or "default"
    self:_save_config()
    if cb then
      cb(nil, self.nixvim[name])
    end
  end
end

-- ---------------------------------------------------------------------------
-- Link resolution
-- ---------------------------------------------------------------------------

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
  log("DEBUG", "resolve_link: dir=" .. tostring(dir))
  -- Collect entries that have a valid link.
  local default_link
  local best_match_link
  local best_match_len = 0

  for _, entry in pairs(self.nixvim) do
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
  log(
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
  log("DEBUG", "get_dir: " .. dir)
  return dir
end

function NixvimManager:_notify(msg, level)
  log("DEBUG", "_notify: msg=" .. msg)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO)
  end)
end

return NixvimManager
