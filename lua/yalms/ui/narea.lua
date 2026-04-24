local EventEmitter = require("yalms.events.emitter")

---@alias Char string
---@class NAreaOpts
---@field kinds? { [string]: string }
---@field win? snacks.win.Config
---@field auto_dismiss? integer

---@class NAreaNotificationOpts
---@field type string
---@field text string
---@field dismiss? integer

---@alias NAreaNotification NAreaNotificationOpts | [string, string][]

---@class NArea: EventEmitter
---@field _opts NAreaOpts
---@field _win snacks.win
---@field _ns integer
---@field _emark? integer
---@field _timer? { close: fun() }
---@field on fun(s: NArea, e: 'n', c: fun(e: 'notification', p: NAreaNotification)) | fun(s: NArea, e: 'notification', c: fun(e: 'notification', p: NAreaNotification))
---@field emit fun(s: NArea, e: 'n', p: NAreaNotification) | fun(s: NArea, e: 'notification', p: NAreaNotification)
---@field handler fun(s: NArea, p: NAreaNotification)
local NArea = {}
NArea.__index = NArea
setmetatable(NArea, { __index = EventEmitter })

---@param opts? NAreaOpts
function NArea:new(opts)
  local Snacks = require("snacks")
  local instance = EventEmitter.new(self)

  ---@cast instance NArea
  instance._opts = opts or {}
  instance._opts.kinds = instance._opts.kinds
    or {
      Info = "",
      Warning = "",
      Error = "",
    }

  ---@type snacks.win.Config
  local wca = {
    width = 0,
    border = "none",
    title = "NArea",
  }

  ---@type snacks.win.Config
  local wcb = {
    rows = 1,
    height = 0.01,
    bo = {
      modifiable = false,
      swapfile = false,
    },
    text = "",
  }

  instance._opts.win = vim.tbl_extend("force", wca, instance._opts.win or {}, wcb)
  instance._win = Snacks.win(instance._opts.win)
  instance._ns = vim.api.nvim_create_namespace("yalms.narea")

  self._handler = function(_, arg)
    instance:_handle_notification(arg)
  end
  ---@diagnostic disable-next-line: param-type-mismatch
  instance:on("notification", self._handler):on("n", self._handler)

  return instance
end

---@param notification NAreaNotification
function NArea:_handle_notification(notification)
  local ok, err = pcall(function()
    if self._timer then
      self._timer:close()
    end

    ---@type integer
    local buf = self._win.buf
    ---@type [string, string][]
    local virt_text

    if type(notification) == "table" and notification.type then
      virt_text = {
        { " " .. self._opts.kinds[notification.type] .. " " .. notification.type, "Bold" },
        { "  " .. notification.text, "@text" },
      }
    else
      virt_text = notification
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.bo[buf].modifiable = false

    self._emark = vim.api.nvim_buf_set_extmark(buf, self._ns, 0, 0, {
      id = self._emark,
      virt_text = virt_text,
      virt_text_pos = "overlay",
    })

    if self._opts.auto_dismiss or notification.dismiss then
      local to = notification.dismiss or self._opts.auto_dismiss

      self._timer = vim.defer_fn(function()
        self:dismiss()
      end, to or 2500)
    end

    self:show()
  end)
end

function NArea:dismiss()
  self:hide()
  ---@type integer
  local buf = self._win.buf
  vim.api.nvim_buf_del_extmark(buf, self._ns, self._emark)
end

function NArea:hide()
  self._win:hide()
end

function NArea:show()
  self._win:show()
end

function NArea:close()
  if self._win and not self._win.closed then
    self._win:close()
  end

  self:off("n", self._handler):off("notification", self._handler)
end

return NArea
