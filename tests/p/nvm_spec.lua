local a = require("plenary.async")
local async = require("plenary.async.tests")

-- ---------------------------------------------------------------------------
-- Unit tests: NixvimManager
-- ---------------------------------------------------------------------------

local get_manager = a.wrap(function(opts, cb)
  opts = opts or {}
  opts.dir = opts.dir or vim.fn.tempname() .. "-nixvim-test"

  NixvimManager = require("yalms.nvm.manager")
  NixvimManager:new({
    dir = opts.dir,
    on_ready = function(err, manager)
      if err then
        cb(nil, err)
      end

      cb(manager)
    end,
  })
end, 2)

async.describe("NixvimManager", function()
  -- -------------------------------------------------------------------------
  async.describe("new", function()
    async.it("creates instance with options", function()
      local manager = get_manager({})
      assert.is_table(manager)
      assert.is_table(manager._opts)
      assert.is_table(manager.nixvim)
      assert.is_table(manager._queue)
    end)
  end)

  -- -------------------------------------------------------------------------
  async.describe("add", function()
    async.it("adds nixvim module", function()
      local manager = get_manager({})

      local err, result = a.wrap(function(callback)
        manager:add({ name = "test-module", initial_content = "{}" }, callback)
      end, 1)()

      assert.is_nil(err)
      assert.is_table(result)
      assert.is_string(result.link)
    end)
  end)
end)
