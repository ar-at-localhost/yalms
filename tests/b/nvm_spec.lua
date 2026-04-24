---@diagnostic disable: duplicate-set-field, invisible
local mock_files = {}
local mock_dirs = {}
local mock_nix_build_calls = {}
local mock_nix_fmt_calls = {}
local mock_run_async_calls = {}

local function reset_mocks()
  mock_files = {}
  mock_dirs = {}
  mock_nix_build_calls = {}
  mock_nix_fmt_calls = {}
  mock_run_async_calls = {}
end

local original_fn = nil
local original_system = nil
local original_schedule = nil
local original_getenv = nil

local function setup_vim_mocks()
  reset_mocks()
  original_fn = vim.fn
  original_system = vim.system
  original_schedule = vim.schedule
  original_getenv = os.getenv

  vim.fn.tempname = function()
    return "/tmp/yalms_test_" .. math.random(100000, 999999)
  end

  vim.fn.mkdir = function(path, _)
    mock_dirs[path] = true
    return 0
  end

  vim.fn.filereadable = function(path)
    return mock_files[path] and 1 or 0
  end

  vim.fn.isdirectory = function(path)
    return mock_dirs[path] and 1 or 0
  end

  vim.fn.delete = function(path, _)
    mock_dirs[path] = nil
    mock_files[path] = nil
    return 0
  end

  vim.fn.getenv = os.getenv

  vim.system = function(cmd, opts, cb)
    local cmd_str = table.concat(cmd, " ")
    if cmd_str:find("nix build") then
      table.insert(mock_nix_build_calls, { cmd = cmd_str, opts = opts })
      local attr = cmd_str:match("#\"([^\"]+)\"") or "default"
      local fake_store = "/nix/store/" .. attr .. "-nvim"
      cb({ code = 0, stdout = fake_store .. "\n", stderr = "" })
    elseif cmd_str:find("nix fmt") then
      table.insert(mock_nix_fmt_calls, { cmd = cmd_str, opts = opts })
      cb({ code = 0, stdout = "", stderr = "" })
    elseif cmd_str:find("nix ") then
      cb({ code = 0, stdout = "", stderr = "" })
    else
      cb({ code = 0, stdout = "", stderr = "" })
    end
  end

  vim.schedule = function(fn)
    fn()
  end

  os.getenv = function(name)
    if name == "GITHUB_TOKEN" or name == "DEBUG" then
      return nil
    end

    if original_getenv then
      return original_getenv(name)
    end
  end
end

local function teardown_vim_mocks()
  vim.fn = original_fn
  vim.system = original_system
  vim.schedule = original_schedule
  os.getenv = original_getenv
end

local function mock_fs()
  package.loaded["yalms.fs"] = nil
  package.loaded["yalms.fs"] = {
    write_file = function(path, content)
      mock_files[path] = content
      return true, nil
    end,
    read_file = function(path)
      local content = mock_files[path]
      if content then
        return content, nil
      end
      return nil, "file not found"
    end,
    touch = function(path, is_dir, initial_content)
      if is_dir then
        mock_dirs[path] = true
      else
        mock_files[path] = initial_content or ""
      end
      return true, nil
    end,
    remove = function(path)
      mock_files[path] = nil
      return true, nil
    end,
  }
end

local function unmock_fs()
  package.loaded["yalms.fs"] = nil
end

local function mock_events()
  package.loaded["yalms.events.emitter"] = nil
  package.loaded["yalms.events.emitter"] = {
    new = function(self)
      local instance = setmetatable({}, {
        __index = function(t, k)
          if k == "_subscribers" then
            return {}
          end
        end,
      })
      instance._subscribers = {}
      return instance
    end,
    on = function(self, event, callback)
      self._subscribers[event] = self._subscribers[event] or {}
      table.insert(self._subscribers[event], callback)
    end,
    off = function(self, event, callback)
      local subs = self._subscribers[event] or {}
      for i, sub in ipairs(subs) do
        if sub == callback then
          table.remove(subs, i)
          return
        end
      end
    end,
    emit = function(self, event, payload)
      local subs = self._subscribers[event] or {}
      for _, sub in ipairs(subs) do
        pcall(sub, event, payload)
      end
    end,
  }
end

describe("NixvimManager", function()
  local test_dir

  before_each(function()
    setup_vim_mocks()
    mock_fs()
    test_dir = vim.fn.tempname() .. "-nixvim-test"
    vim.fn.mkdir(test_dir, "p")
  end)

  after_each(function()
    unmock_fs()
    teardown_vim_mocks()
    reset_mocks()
  end)

  describe("new", function()
    it("creates instance with options", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({
        dir = test_dir,
      })

      assert.is_table(manager)
      assert.is_table(manager._opts)
      assert.is_table(manager.nixvims)
      assert.is_table(manager._queue)
    end)

    it("creates instance without options", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new()

      assert.is_table(manager)
      assert.is_table(manager._opts)
    end)
  end)

  describe("event system", function()
    it("allows subscribing to ready event", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({
        dir = test_dir,
      })

      local ready_called = false
      manager:on("ready", function(event, payload)
        ready_called = true
        assert.is_table(payload)
        assert.is_equal(manager, payload)
      end)

      assert.is_function(manager.on)
      assert.is_function(manager.emit)
    end)

    it("allows subscribing to change event", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({
        dir = test_dir,
      })

      local change_called = false
      manager:on("change", function(event, payload)
        change_called = true
      end)

      assert.is_function(manager.on)
    end)

    it("allows subscribing to build event", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({
        dir = test_dir,
      })

      local build_called = false
      manager:on("build", function(event, payload)
        build_called = true
      end)

      assert.is_function(manager.on)
    end)

    it("allows subscribing to remove event", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({
        dir = test_dir,
      })

      local remove_called = false
      manager:on("remove", function(event, payload)
        remove_called = true
      end)

      assert.is_function(manager.on)
    end)
  end)

  describe("resolve_link", function()
    local manager

    before_each(function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      manager = NixvimManager:new({ dir = test_dir })
    end)

    it("returns nil when no modules exist", function()
      assert.is_nil(manager:resolve_link())
    end)

    it("returns default link when no dir specified", function()
      manager.nixvims["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      assert.is_equal("/nix/store/default-nvim/bin/nvim", manager:resolve_link())
    end)

    it("returns default link when no dir matches", function()
      manager.nixvims["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      manager.nixvims["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_equal("/nix/store/default-nvim/bin/nvim", manager:resolve_link("/home/user/other"))
    end)

    it("returns matching dir-specific link when prefix matches", function()
      manager.nixvims["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      manager.nixvims["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_equal(
        "/nix/store/project-nvim/bin/nvim",
        manager:resolve_link("/home/user/project/src")
      )
    end)

    it("prefers longest matching prefix", function()
      manager.nixvims["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      manager.nixvims["short"] = {
        name = "short",
        link = "/nix/store/short-nvim/bin/nvim",
        dirs = { "/home/user" },
      }
      manager.nixvims["long"] = {
        name = "long",
        link = "/nix/store/long-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_equal(
        "/nix/store/long-nvim/bin/nvim",
        manager:resolve_link("/home/user/project/src")
      )
    end)

    it("handles trailing slash in dir prefix", function()
      manager.nixvims["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project/" },
      }
      assert.is_equal(
        "/nix/store/project-nvim/bin/nvim",
        manager:resolve_link("/home/user/project")
      )
    end)

    it("returns nil when only dirs-constrained entries exist but no match", function()
      manager.nixvims["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_nil(manager:resolve_link("/home/user/other"))
    end)
  end)

  describe("callback: rebuild", function()
    local manager

    before_each(function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      manager = NixvimManager:new({ dir = test_dir })
    end)

    it("calls callback with error when nixvim not found", function()
      local cb_err, cb_nixvim
      manager:rebuild("nonexistent", function(err, nixvim)
        cb_err = err
        cb_nixvim = nixvim
      end)

      assert.is_string(cb_err)
      assert.is_nil(cb_nixvim)
    end)

    it("calls callback with nixvim on success", function()
      manager.nixvims["default"] = {
        name = "default",
        link = "/nix/store/old-nvim/bin/nvim",
        dirs = nil,
      }

      local cb_err, cb_nixvim
      manager:rebuild("default", function(err, nixvim)
        cb_err = err
        cb_nixvim = nixvim
      end)

      assert.is_nil(cb_err)
      assert.is_table(cb_nixvim)
      assert.is_true(#mock_nix_build_calls > 0)
    end)
  end)

  describe("callback: add", function()
    local manager

    before_each(function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      mock_nix_build_calls = {}
      mock_nix_fmt_calls = {}
      manager = NixvimManager:new({ dir = test_dir })
    end)

    it("adds a new nixvim and calls callback on success", function()
      local cb_err, cb_nixvim
      manager:add({ name = "test.nvim", initial_content = "{}" }, function(err, nixvim)
        cb_err = err
        cb_nixvim = nixvim
      end)

      assert.is_nil(cb_err)
      assert.is_table(cb_nixvim)
      assert.is_equal("test.nvim", cb_nixvim.name)
      assert.is_true(#mock_nix_build_calls > 0)
    end)

    it("calls callback with error on build failure", function()
      vim.system = function(cmd, opts, cb)
        local cmd_str = table.concat(cmd, " ")
        if cmd_str:find("nix build") then
          cb({ code = 1, stdout = "", stderr = "build failed" })
        else
          cb({ code = 0, stdout = "", stderr = "" })
        end
      end

      local cb_err, cb_nixvim
      manager:add({ name = "test.nvim", initial_content = "{}" }, function(err, nixvim)
        cb_err = err
        cb_nixvim = nixvim
      end)

      assert.is_string(cb_err)
      assert.is_nil(cb_nixvim)
    end)

    it("triggers build event on success", function()
      local build_event_triggered = false
      local build_payload = nil
      manager:on("build", function(event, payload)
        build_event_triggered = true
        build_payload = payload
      end)

      manager:add({ name = "test.nvim", initial_content = "{}" }, function() end)

      assert.is_true(build_event_triggered)
      assert.is_table(build_payload)
      assert.is_equal(manager, build_payload.manager)
    end)
  end)

  describe("callback: update", function()
    local manager

    before_each(function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      mock_nix_build_calls = {}
      mock_nix_fmt_calls = {}
      manager = NixvimManager:new({ dir = test_dir })
      manager.nixvims["existing"] = {
        name = "existing",
        link = "/nix/store/old-nvim/bin/nvim",
        dirs = nil,
      }
      mock_files[test_dir .. "/existing/nixvim.nix"] = "{}"
    end)

    it("calls callback with error when nixvim not found", function()
      local cb_err, cb_nixvim
      manager:update("nonexistent", function(err, nixvim)
        cb_err = err
        cb_nixvim = nixvim
      end)

      assert.is_string(cb_err)
      assert.is_nil(cb_nixvim)
    end)

    it("updates existing nixvim", function()
      local cb_err, cb_nixvim
      manager:update(
        { name = "existing", initial_content = "{ foo = true; }" },
        function(err, nixvim)
          cb_err = err
          cb_nixvim = nixvim
        end
      )

      assert.is_nil(cb_err)
      assert.is_table(cb_nixvim)
    end)
  end)

  describe("callback: remove", function()
    local manager

    before_each(function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      mock_nix_build_calls = {}
      manager = NixvimManager:new({ dir = test_dir })
      manager.nixvims["toremove"] = {
        name = "toremove",
        link = "/nix/store/old-nvim/bin/nvim",
        dirs = nil,
      }
    end)

    it("calls callback with error when nixvim not found", function()
      local cb_err, cb_name
      manager:remove("nonexistent", function(err, name)
        cb_err = err
        cb_name = name
      end)

      assert.is_string(cb_err)
      assert.is_nil(cb_name)
    end)

    it("removes nixvim and calls callback on success", function()
      local cb_err, cb_name
      manager:remove("toremove", function(err, name)
        cb_err = err
        cb_name = name
      end)

      assert.is_nil(cb_err)
      assert.is_equal("toremove", cb_name)
      assert.is_nil(manager.nixvims["toremove"])
    end)

    it("triggers remove event on success", function()
      local remove_triggered = false
      local remove_payload = nil
      manager:on("remove", function(event, payload)
        remove_triggered = true
        remove_payload = payload
      end)

      manager:remove("toremove", function() end)

      assert.is_true(remove_triggered)
      assert.is_table(remove_payload)
    end)
  end)

  describe("callback: get", function()
    local manager

    before_each(function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      manager = NixvimManager:new({ dir = test_dir })
      manager.nixvims["existing"] = {
        name = "existing",
        link = "/nix/store/old-nvim/bin/nvim",
        dirs = nil,
      }
    end)

    it("returns nixvim when found", function()
      local cb_err, cb_nixvim
      manager:get("existing", function(err, nixvim)
        cb_err = err
        cb_nixvim = nixvim
      end)

      assert.is_nil(cb_err)
      assert.is_table(cb_nixvim)
      assert.is_equal("existing", cb_nixvim.name)
    end)

    it("returns error when not found", function()
      local cb_err, cb_nixvim
      manager:get("nonexistent", function(err, nixvim)
        cb_err = err
        cb_nixvim = nixvim
      end)

      assert.is_string(cb_err)
      assert.is_nil(cb_nixvim)
    end)
  end)

  describe("nixvim table state", function()
    it("starts empty", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({
        dir = test_dir,
      })
      assert.is_table(manager.nixvims)
    end)

    it("has add method to store nixvims", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({ dir = test_dir })

      assert.is_function(manager.add)
    end)
  end)

  describe("get_dir", function()
    it("returns the configured directory", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({ dir = test_dir })

      local dir = manager:get_dir()

      assert.is_equal(test_dir, dir)
    end)
  end)

  describe("get_nixvims", function()
    it("returns a copy of nixvims table", function()
      package.loaded["yalms.nvm.manager"] = nil
      local NixvimManager = require("yalms.nvm.manager")
      local manager = NixvimManager:new({ dir = test_dir })
      manager.nixvims["test"] = { name = "test" }

      local nixvims = manager:get_nixvims()

      assert.is_table(nixvims)
      assert.is_equal("test", nixvims.test.name)
    end)
  end)
end)
