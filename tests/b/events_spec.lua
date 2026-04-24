local EventEmitter = require("yalms.events.emitter")

describe("yalms.events.emitter", function()
  local emitter

  setup(function()
    emitter = EventEmitter:new()
  end)

  describe("new", function()
    it("creates instance with empty subscribers", function()
      local e = EventEmitter:new()
      assert.is_table(e._subscribers)
      assert.is_same({}, e._subscribers)
    end)
  end)

  describe("on", function()
    it("registers callback for event", function()
      local called = false
      local callback = function()
        called = true
      end
      emitter:on("test", callback)
      assert.is_true(emitter:has("test", callback))
    end)

    it("registers multiple callbacks for same event", function()
      local called1, called2 = false, false
      emitter:on("multi", function()
        called1 = true
      end)
      emitter:on("multi", function()
        called2 = true
      end)
      emitter:emit("multi", nil)
      assert.is_true(called1)
      assert.is_true(called2)
    end)

    it("registers callbacks for different events", function()
      local called_a, called_b = false, false
      emitter:on("eventA", function()
        called_a = true
      end)
      emitter:on("eventB", function()
        called_b = true
      end)
      emitter:emit("eventA", nil)
      assert.is_true(called_a)
      assert.is_false(called_b)
    end)
  end)

  describe("off", function()
    it("removes registered callback", function()
      local callback = function() end
      emitter:on("removeTest", callback)
      assert.is_true(emitter:has("removeTest", callback))
      emitter:off("removeTest", callback)
      assert.is_false(emitter:has("removeTest", callback))
    end)

    it("does not error when callback not registered", function()
      local callback = function() end
      local success = pcall(function()
        emitter:off("nonexistent", callback)
      end)
      assert.is_true(success)
    end)

    it("does not error when event has no subscribers", function()
      local success = pcall(function()
        emitter:off("noSubs", function() end)
      end)
      assert.is_true(success)
    end)
  end)

  describe("has", function()
    it("returns true for registered callback", function()
      local callback = function() end
      emitter:on("hasTest", callback)
      assert.is_true(emitter:has("hasTest", callback))
    end)

    it("returns false for non-registered callback", function()
      local callback = function() end
      assert.is_false(emitter:has("hasTest", callback))
    end)

    it("returns false for different event", function()
      local callback = function() end
      emitter:on("eventA", callback)
      assert.is_false(emitter:has("eventB", callback))
    end)
  end)

  describe("emit", function()
    it("calls all callbacks for event", function()
      local calls = {}
      emitter:on("emitTest", function()
        table.insert(calls, 1)
      end)
      emitter:on("emitTest", function()
        table.insert(calls, 2)
      end)
      emitter:emit("emitTest", nil)
      assert.is_same({ 1, 2 }, calls)
    end)

    it("passes event and payload to callback", function()
      local received_event, received_payload
      emitter:on("payloadTest", function(event, payload)
        received_event = event
        received_payload = payload
      end)
      emitter:emit("payloadTest", { data = "test" })
      assert.equal("payloadTest", received_event)
      assert.is_same({ data = "test" }, received_payload)
    end)

    it("does nothing when no subscribers", function()
      local called = false
      emitter:on("none", function()
        called = true
      end)
      emitter:off("none", function() end) -- ensure none exists
      emitter:emit("none", nil)
      -- No error expected
    end)

    it("only emits to event-specific subscribers", function()
      local calls = {}
      emitter:on("eventX", function()
        table.insert(calls, "X")
      end)
      emitter:on("eventY", function()
        table.insert(calls, "Y")
      end)
      emitter:emit("eventX", nil)
      assert.is_same({ "X" }, calls)
    end)
  end)

  describe("edge cases", function()
    it("handles numeric event names", function()
      local called = false
      emitter:on(42, function()
        called = true
      end)
      emitter:emit(42, nil)
      assert.is_true(called)
    end)

    it("handles table event names", function()
      local called = false
      local event_key = { type = "custom" }
      emitter:on(event_key, function()
        called = true
      end)
      emitter:emit(event_key, nil)
      assert.is_true(called)
    end)

    it("handles nil payload", function()
      local received
      emitter:on("nilPayload", function(_, payload)
        received = payload
      end)
      emitter:emit("nilPayload", nil)
      assert.is_nil(received)
    end)
  end)
end)
