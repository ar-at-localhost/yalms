---@class NixvimPickerConfig :snacks.picker.Config
---@field manager? NixvimManager
---@field hooks? Hooks

---@class Hooks
---@field notify fun(err: string|nil, manager: NixvimManager, item: NixvimPickerItem)

---@class NixvimPickerItem
---@field name string
---@field nixvim Nixvim
---@field preview { ft: string, text: string }

local keys = {
  ["<a-r>"] = {
    "rebuild",
    mode = { "n", "v" },
  },
  ["<a-e>"] = {
    "edit",
    mode = { "n", "v" },
  },
  ["<a-d>"] = {
    "delete",
    mode = { "n", "v" },
  },
  ["<a-+>"] = {
    "add",
    mode = { "n", "v" },
  },
}

local function make_action(cb, kind, action_name)
  return function(picker, item)
    local function call_hook(err)
      picker.opts.hooks.notify(err, picker.opts.manager, item)
    end

    cb(item, picker, call_hook)

    if kind == "filter" then
      return picker:find()
    elseif kind == "mutation" then
      return picker:refresh()
    elseif kind == "done" then
      picker:close()
    end
  end
end

local nixvim_picker = {
  text = "name",
  preview = "preview",

  format = function(item)
    return {
      { "◆ " },
      { item.name },
    }
  end,

  finder = function(opts)
    opts = opts or {}
    local items = {}
    local manager = opts.manager or G.__nixvim_manager_nvim

    if not manager then
      return items
    end

    for name, nixvim in pairs(manager.nixvim) do
      local dirs = nixvim.dirs or {}
      table.insert(items, {
        name = name,
        nixvim = nixvim,
        preview = {
          ft = "markdown",
          text = string.format(
            [[
### %s

- **Binary Path**: %s
- **Directories**:
%s
]],
            name,
            nixvim.link or "N/A",
            #dirs >= 1 and ("    - " .. table.concat(nixvim.dirs or {}, "\n    - ")) or "    None"
          ),
        },
      })
    end

    return items
  end,

  actions = {
    rebuild = make_action(function(item, picker, call_hook)
      local manager = picker.opts.manager
      if not manager then
        return
      end
      call_hook(nil)
    end, "mutation", "rebuild"),

    edit = make_action(function(item, picker, call_hook)
      local manager = picker.opts.manager
      if not manager then
        return
      end

      vim.defer_fn(function()
        local buf = vim.api.nvim_create_buf(false, true)
        local path = item.nixvim.path
        local ok, content = pcall(vim.fn.readfile, path)
        if ok and content then
          vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
        end

        vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = math.floor(vim.o.columns * 0.8),
          height = math.floor(vim.o.lines * 0.8),
          row = math.floor(vim.o.lines * 0.1),
          col = math.floor(vim.o.columns * 0.1),
          border = "rounded",
          title = "Edit: " .. item.name,
        })
        call_hook(nil)
      end, 10)
    end, "none", "edit"),

    delete = make_action(function(item, picker, call_hook)
      local manager = picker.opts.manager
      if not manager then
        return
      end

      manager:remove(item.name, function(err)
        call_hook(err)
        picker:refresh()
      end)
    end, "mutation", "delete"),

    add = make_action(function(_, picker, call_hook)
      local manager = picker.opts.manager
      if not manager then
        return
      end

      vim.ui.input({ prompt = "Name: " }, function(name)
        if not name or name == "" then
          return
        end

        local temp_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_open_win(temp_buf, true, {
          relative = "editor",
          width = math.floor(vim.o.columns * 0.8),
          height = math.floor(vim.o.lines * 0.8),
          row = math.floor(vim.o.lines * 0.1),
          col = math.floor(vim.o.columns * 0.1),
          border = "rounded",
          title = "New nixvim: " .. name,
        })

        local ns = vim.api.nvim_create_namespace("nixvim_edit")
        vim.bo[temp_buf].filetype = "nix"

        vim.api.nvim_buf_attach(temp_buf, false, {
          on_detach = function()
            local lines = vim.api.nvim_buf_get_lines(temp_buf, 0, -1, true)
            local content = table.concat(lines, "\n")

            manager:add(name, content, function(err)
              call_hook(err)
              picker:refresh()
            end)
          end,
        })
      end)
    end, "mutation", "add"),
  },

  confirm = function(picker, item) end,

  hooks = {
    notify = function(err, manager, item)
      if err then
        vim.notify(("Action failed: %s"):format(err), vim.log.levels.ERROR)
      else
        vim.notify("Action succeeded", vim.log.levels.INFO)
      end
    end,
  },

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
}

---@type snacks.picker.Config
local M = vim.tbl_extend("force", {
  ft = "text",
  title_format = "both",
  auto_confirm = false,
  auto_close = false,
  hooks = nixvim_picker.hooks,
}, nixvim_picker)

return M
