local a = require("plenary.async")
local async = require("plenary.async.tests")

local EventEmitter = require("yalms.events.emitter")

describe("yalms.events.emitter async", function()
  describe("async listener callbacks", function()
    async.it("handles delayed callback via vim.defer_fn", function()
      local emitter = EventEmitter:new()
      local completed = false

      local function async_callback(event, payload)
        vim.defer_fn(function()
          completed = true
        end, 10)
      end

      emitter:on("asyncEvent", async_callback)
      emitter:emit("asyncEvent", nil)

      vim.defer_fn(function()
        assert.is_true(completed)
      end, 50)
    end)

    async.it("handles multiple rapid emissions", function()
      local emitter = EventEmitter:new()
      local call_count = 0

      for i = 1, 10 do
        emitter:on("rapid", function()
          call_count = call_count + 1
        end)
      end

      for _ = 1, 5 do
        emitter:emit("rapid", nil)
      end

      assert.equal(10 * 5, call_count)
    end)

    async.it("rapidly adds and removes listeners", function()
      local emitter = EventEmitter:new()
      local total_calls = 0

      local function make_callback()
        local callback = function()
          total_calls = total_calls + 1
        end
        emitter:on("fluctuate", callback)
        return callback
      end

      for i = 1, 20 do
        local cb = make_callback()
        if i % 2 == 0 then
          emitter:off("fluctuate", cb)
        end
      end

      emitter:emit("fluctuate", nil)
      assert.equal(10, total_calls)
    end)
  end)

  describe("error handling", function()
    async.it("catches errors silently, continues calling all listeners", function()
      local emitter = EventEmitter:new()
      local reached_third = false

      emitter:on("error", function()
        error("intentional error")
      end)

      emitter:on("error", function()
        error("another error")
      end)

      emitter:on("error", function()
        reached_third = true
      end)

      emitter:emit("error", nil)

      assert.is_true(reached_third)
    end)

    async.it("continues after error, all callbacks execute", function()
      local emitter = EventEmitter:new()
      local call_count = 0

      emitter:on("loop", function()
        call_count = call_count + 1
      end)

      emitter:on("loop", function()
        error("stop here")
      end)

      emitter:on("loop", function()
        call_count = call_count + 1
      end)

      emitter:emit("loop", nil)

      assert.equal(2, call_count)
    end)
  end)

  describe("stress tests", function()
    async.it("handles many unique events", function()
      local emitter = EventEmitter:new()

      for i = 1, 100 do
        local event_name = "event_" .. i
        local called = false
        emitter:on(event_name, function()
          called = true
        end)
        emitter:emit(event_name, nil)
        assert.is_true(called)
      end
    end)

    async.it("handles large payload tables", function()
      local emitter = EventEmitter:new()
      local received_payload

      local large_payload = {}
      for i = 1, 1000 do
        large_payload[i] = "value_" .. i
      end

      emitter:on("large", function(_, payload)
        received_payload = payload
      end)

      emitter:emit("large", large_payload)

      assert.is_same(large_payload, received_payload)
      assert.equal(1000, #received_payload)
    end)

    async.it("concurrent emit from multiple sources", function()
      local emitter = EventEmitter:new()
      local results = {}

      emitter:on("concurrent", function(event, payload)
        table.insert(results, { event = event, payload = payload })
      end)

      for i = 1, 50 do
        emitter:emit("concurrent", { id = i })
      end

      assert.equal(50, #results)
    end)
  end)
end)
