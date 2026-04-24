local NArea = require("yalms.ui.narea")

describe("yalms.ui.narea", function()
  local mock_win
  local mock_buf
  local mock_ns
  local original_api
  local original_snacks

  setup(function()
    mock_buf = 1
    mock_ns = 10
    mock_win = {
      buf = mock_buf,
      show = function() end,
      hide = function() end,
    }

    original_api = vim.api
    vim.api = {
      nvim_create_namespace = function(_)
        return mock_ns
      end,
      nvim_buf_set_lines = function() end,
      nvim_buf_set_extmark = function(_, _, _, _, opts)
        return 1
      end,
      nvim_buf_del_extmark = function() end,
    }

    original_snacks = require("snacks")
    local Snacks = {}
    Snacks.win = function()
      return mock_win
    end
    Snacks.picker = {}
    Snacks.picker.bold = ""
    package.loaded["snacks"] = Snacks
  end)

  teardown(function()
    vim.api = original_api
    package.loaded["snacks"] = original_snacks
  end)

  describe("new", function()
    it("creates instance with default kinds as map", function()
      local area = NArea:new()
      assert.is_table(area._opts)
      assert.is_table(area._opts.kinds)
      assert.equal("", area._opts.kinds.Info)
      assert.equal("", area._opts.kinds.Warning)
      assert.equal("", area._opts.kinds.Error)
    end)

    it("accepts custom kinds", function()
      local custom_kinds = { Custom = "★" }
      local area = NArea:new({ kinds = custom_kinds })
      assert.is_same(custom_kinds, area._opts.kinds)
    end)

    it("merges default win config with custom options", function()
      local area = NArea:new({
        win = {
          width = 50,
          height = 10,
        },
      })
      assert.equal(50, area._opts.win.width)
      assert.equal(10, area._opts.win.height)
      assert.equal(1, area._opts.win.rows)
      assert.equal("", area._opts.win.text)
      assert.is_table(area._opts.win.bo)
      assert.is_false(area._opts.win.bo.modifiable)
      assert.is_false(area._opts.win.bo.swapfile)
    end)

    it("sets up event handlers", function()
      local area = NArea:new()
      local has_notification, has_n = false, false
      for event, _ in pairs(area._subscribers or {}) do
        if event == "notification" then
          has_notification = true
        end
        if event == "n" then
          has_n = true
        end
      end
      assert.is_true(has_notification)
      assert.is_true(has_n)
    end)

    it("creates namespace", function()
      local area = NArea:new()
      assert.equal(mock_ns, area._ns)
    end)

    it("stores window instance", function()
      local area = NArea:new()
      assert.is_table(area._win)
    end)
  end)

  describe("_handle_notification", function()
    it("handles typed format with type and text", function()
      local set_extmark_calls = {}
      vim.api.nvim_buf_set_extmark = function(buf, ns, row, col, opts)
        table.insert(set_extmark_calls, { buf, ns, row, col, opts })
      end

      local area = NArea:new()
      area:_handle_notification({ type = "Info", text = "test message" })
      assert.equal(1, #set_extmark_calls)
      local call = set_extmark_calls[1]
      assert.equal(mock_buf, call[1])
      assert.equal(mock_ns, call[2])
      assert.is_table(call[5].virt_text)
      local virt = call[5].virt_text
      assert.equal(5, #virt)
      assert.is_same({ "", "SnacksPickerBold" }, virt[1])
      assert.is_same({ "  ", "Normal" }, virt[2])
      assert.is_same({ "Info", "SnacksPickerBold" }, virt[3])
      assert.is_same({ " ", "Normal" }, virt[4])
      assert.is_same({ "test message", "SnacksPicker" }, virt[5])
      assert.equal("overlay", call[5].virt_text_pos)
    end)

    it("handles array format", function()
      local set_extmark_calls = {}
      vim.api.nvim_buf_set_extmark = function(buf, ns, row, col, opts)
        table.insert(set_extmark_calls, { buf, ns, row, col, opts })
      end

      local area = NArea:new()
      local arr = { { "prefix", "Highlight" }, { " body", "Normal" } }
      area:_handle_notification(arr)
      assert.equal(1, #set_extmark_calls)
      local call = set_extmark_calls[1]
      assert.is_same(arr, call[5].virt_text)
      assert.equal("overlay", call[5].virt_text_pos)
    end)

    it("stores extmark id", function()
      local set_extmark_result
      vim.api.nvim_buf_set_extmark = function(buf, ns, row, col, opts)
        set_extmark_result = 42
        return set_extmark_result
      end

      local area = NArea:new()
      area:_handle_notification({ type = "Info", text = "test" })
      assert.is_number(area._emark)
      assert.equal(42, area._emark)
    end)

    it("shows the window", function()
      local show_called = false
      mock_win.show = function()
        show_called = true
      end
      local area = NArea:new()
      area:_handle_notification({ type = "Info", text = "test" })
      assert.is_true(show_called)
    end)

    it("closes previous timer on new notification", function()
      local closed = false
      local area = NArea:new()
      area._timer = {
        close = function()
          closed = true
        end,
      }
      area:_handle_notification({ type = "Info", text = "test" })
      assert.is_true(closed)
    end)

    it("handles auto_dismiss timeout", function()
      vim.defer_fn = function(fn, timeout)
        assert.is_function(fn)
        assert.equal(2500, timeout)
      end

      local area = NArea:new({ auto_dismiss = 2500 })
      area:_handle_notification({ type = "Info", text = "test" })
    end)

    it("handles notification-specific dismiss timeout", function()
      local defer_calls = {}
      vim.defer_fn = function(fn, timeout)
        table.insert(defer_calls, { fn = fn, timeout = timeout })
      end

      local area = NArea:new()
      area:_handle_notification({ type = "Info", text = "test", dismiss = 1000 })
      assert.equal(1, #defer_calls)
      assert.equal(1000, defer_calls[1].timeout)
    end)

    it("prioritizes notification dismiss over auto_dismiss", function()
      local defer_calls = {}
      vim.defer_fn = function(fn, timeout)
        table.insert(defer_calls, { fn = fn, timeout = timeout })
      end

      local area = NArea:new({ auto_dismiss = 5000 })
      area:_handle_notification({ type = "Info", text = "test", dismiss = 3000 })
      assert.equal(3000, defer_calls[1].timeout)
    end)

    it("does not schedule dismiss when no timeout set", function()
      local defer_called = false
      vim.defer_fn = function()
        defer_called = true
      end

      local area = NArea:new()
      area:_handle_notification({ type = "Info", text = "test" })
      assert.is_false(defer_called)
    end)
  end)

  describe("dismiss", function()
    it("hides the window", function()
      local hide_called = false
      local area = NArea:new()
      area._win.hide = function()
        hide_called = true
      end
      area:dismiss()
      assert.is_true(hide_called)
    end)

    it("deletes the extmark", function()
      local del_extmark_calls = {}
      vim.api.nvim_buf_del_extmark = function(buf, ns, id)
        table.insert(del_extmark_calls, { buf = buf, ns = ns, id = id })
      end

      local area = NArea:new()
      area._emark = 5
      area:dismiss()
      assert.equal(1, #del_extmark_calls)
      assert.equal(mock_buf, del_extmark_calls[1].buf)
      assert.equal(mock_ns, del_extmark_calls[1].ns)
      assert.equal(5, del_extmark_calls[1].id)
    end)
  end)

  describe("show", function()
    it("shows the window", function()
      local show_called = false
      mock_win.show = function()
        show_called = true
      end
      local area = NArea:new()
      area:show()
      assert.is_true(show_called)
    end)
  end)

  describe("hide", function()
    it("hides the window", function()
      local hide_called = false
      mock_win.hide = function()
        hide_called = true
      end
      local area = NArea:new()
      area:hide()
      assert.is_true(hide_called)
    end)
  end)

  describe("event inheritance", function()
    it("inherits from EventEmitter", function()
      local area = NArea:new()
      assert.is_function(area.on)
      assert.is_function(area.off)
      assert.is_function(area.emit)
      assert.is_function(area.has)
    end)

    it("can emit custom events", function()
      local area = NArea:new()
      local called = false
      area:on("custom", function()
        called = true
      end)
      area:emit("custom", nil)
      assert.is_true(called)
    end)
  end)
end)
