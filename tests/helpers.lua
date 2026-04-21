local M = {}
local dkjson = require("dkjson")

M.json = {
  encode = function(val)
    return dkjson.encode(val, { indent = false })
  end,
  decode = function(str)
    return dkjson.decode(str)
  end,
}

function M.mock_vim()
  _G.vim = {
    api = {},
    json = M.json,
    fn = {
      getenv = os.getenv,
    },
  }
end

function M.unmock_vim()
  _G.vim = nil
end

function M.mock_wezterm()
  _G.wezterm = {
    json_encode = M.json.encode,
    json_parse = M.json.decode,
  }
end

function M.unmock_wezterm()
  _G.wezterm = nil
end

function M.temp_dir()
  local f = io.popen("mktemp -d")
  local dir = f:read("*a"):gsub("\n", "")
  f:close()
  return dir
end

function M.cleanup_dir(dir)
  os.execute("rm -rf " .. dir)
end

return M
