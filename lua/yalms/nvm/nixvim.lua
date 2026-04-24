require("plenary.reload")
local characters = require("yalms.nvm.characters")
---@class NixvimPickerConfig :snacks.picker.Config
---@field manager? NixvimManager
---@field narea? NArea
---@field events? EventEmitter

---@class NixvimPicker :snacks.Picker
---@field opts NixvimPickerConfig
---@field narea? NArea
---@field manager? NixvimManager
---@field _last_focused_win snacks.win

---@class NixvimPickerFinderCtx: snacks.picker.finder.ctx
---@field picker NixvimPicker

---@class NixvimPickerItem
---@field name string
---@field nixvim Nixvim
---@field preview { ft: string, text: string }

local keys = {
  ["<M-b>"] = {
    "build",
    mode = { "n", "v" },
  },
  ["<M-e>"] = {
    "edit",
    mode = { "n", "v" },
  },
  ["<M-d>"] = {
    "delete",
    mode = { "n", "v" },
  },
  ["<M-a>"] = {
    "add",
    mode = { "n", "v" },
  },
  ["<M-j>"] = {
    "rotate-focus",
    mode = { "n", "v" },
  },
}

---@type snacks.picker.Config
local M = vim.tbl_extend("force", {
  ft = "text",
  title_format = "both",
  auto_confirm = false,
  auto_close = false,
  show_empty = true,
} --[[@as snacks.picker.Config]], {
  text = "name",
  preview = "preview",

  format = function(item)
    return {
      { characters[item.status] or characters.unknown },
      { " " .. item.name },
    }
  end,

  ---@param opts NixvimPickerConfig
  ---@param ctx NixvimPickerFinderCtx
  finder = function(opts, ctx)
    opts = opts or {}
    local items = {}
    local manager = ctx.picker.manager

    if not manager then
      return items
    end

    local nixvims = manager:get_nixvims()
    for name, nixvim in pairs(nixvims) do
      local dirs = nixvim.dirs or {}
      table.insert(items, {
        name = name,
        nixvim = nixvim,
        status = nixvim.status,
        preview = {
          ft = "markdown",
          text = string.format(
            [[
### %s

- **Module**: %s
- **Binary**: %s
- **Directories**:
%s
]],
            name,
            nixvim.module or "N/A",
            nixvim.link or "N/A",
            #dirs >= 1 and ("    - " .. table.concat(nixvim.dirs or {}, "\n    - ")) or "    None"
          ),
        },
      })
    end

    return items
  end,

  actions = {
    ---@param picker NixvimPicker
    ---@param item NixvimPickerItem
    build = function(picker, item)
      return picker.narea:emit("n", {
        type = "Info",
        text = "Building " .. item.name,
      })
    end,

    ---@param picker NixvimPicker
    ---@param item NixvimPickerItem
    edit = function(picker, item)
      local buf = vim.api.nvim_create_buf(false, true)
      local path = item.nixvim.module
      local ok, content_or_err = pcall(vim.fn.readfile, path)

      if ok then
        Snacks.win({
          title = "Edit " .. item.name,
          position = "float",
          relative = "editor",
          buf = buf,
          text = content_or_err,
          zindex = 1000,
          width = 0.9,
          height = 0.9,
          on_close = function()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local write_ok, write_err = pcall(vim.fn.writefile, lines, path)

            if write_ok then
              picker:action("rebuild")
            else
              return picker.narea:emit("n", {
                type = "Error",
                text = tostring(write_err),
              })
            end
          end,
        })
      else
        return picker.narea:emit("n", {
          type = "Error",
          text = tostring(content_or_err),
        })
      end
    end,

    ---@param item NixvimPickerItem
    ---@param picker NixvimPicker
    delete = function(item, picker)
      vim.defer_fn(function()
        picker.narea:emit("n", {
          type = "Info",
          text = "Deleteing " .. item.name,
        })

        picker.manager:remove(item.name, function(err)
          picker:refresh()
        end)
      end, 0)
    end,

    ---@param picker NixvimPicker
    add = function(_, picker)
      local manager = picker.manager
      if not manager then
        return
      end

      vim.ui.input({ prompt = "Name: " }, function(name)
        if not name or name == "" then
          return
        end

        local buf = vim.api.nvim_create_buf(false, true)
        local default_content = { "{ pkgs, nixvim, builds, ...}: {}" }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, default_content)
        vim.api.nvim_set_option_value("filetype", "nix", { buf = buf })

        Snacks.win({
          title = "Create new Nixvim",
          position = "float",
          buf = buf,
          footer_keys = { "create" },
          enter = false,
          keys = {
            ["create"] = {
              "<C-s>",
              "create",
            },
          },
          create = function(_)
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local content = table.concat(lines, "\n")

            if content == "" then
              return
            end

            manager:add({
              name = name,
              initial_content = content,
            })
          end,
        })
      end)
    end,

    ---@param picker NixvimPicker
    rotate_focus = function(_, picker)
      ---@type snacks.win
      local next

      if not picker._last_focused_win or picker._last_focused_win.id ~= picker.narea._win.id then
        next = picker.narea._win
      else
        next = picker._last_focused_win or picker.layout.wins.input
      end

      picker._last_focused_win = next
      next:focus()
    end,
  },

  confirm = function()
    --- important: do nothing
  end,

  layout = require("snacks.picker.config").layout("default"),

  ---@param picker NixvimPicker
  on_show = function(picker)
    local events = picker.opts.events
    if not events then
      local EventEmitter = require("yalms.events.emitter")
      events = EventEmitter:new()
    end
    picker.opts.events = events

    local narea = picker.narea

    if not narea then
      local NArea = require("yalms.ui.narea")
      local win = picker.layout.root
      local win_id = win.win
      local win_size = win:size()
      local zindex = picker.layout.root.opts.zindex

      narea = NArea:new({
        win = {
          position = "float",
          relative = "win",
          win = win_id,
          anchor = "NW",
          col = 0,
          row = win_size.height,
          width = win_size.width,
          zindex = zindex,

          actions = {
            rotate_focus = function()
              vim.print("Rotating focus...")
              picker:focus()
            end,
          },

          keys = {
            ["<M-k>"] = "rotate_focus",
          },
        },
      })
    end
    picker.narea = narea

    narea:emit("notification", {
      type = "Info",
      text = "NixvimManager is loading...",
    })

    local manager = picker.manager
    if not manager then
      manager = require("yalms.nvm").setup({})
    end
    picker.manager = manager

    local on_change = function()
      vim.defer_fn(function()
        picker:find()
      end, 0)
    end

    manager:on("index", on_change):on("change", on_change)
    manager:reload(function()
      vim.defer_fn(function()
        picker:find()
        narea:emit("n", {
          type = "Info",
          text = "NixvimManager is ready.",
        })
      end, 0)
    end)

    picker:focus()
  end,

  ---@param picker NixvimPicker
  on_close = function(picker)
    if picker.narea then
      picker.narea:hide()
    end
  end,

  win = {
    input = {
      keys = keys,
    },
    list = {
      keys = keys,
    },
  },

  matcher = {
    sort_empty = true,
  },

  sort = {
    fields = { "name" },
  },
} --[[@as snacks.picker.Config]])

return M
