---@class NixvimManagerUtils
local NixvimManagerUtils = {}
local DEBUG = os.getenv("DEBUG")
local DEV = os.getenv("YALMS_DEV")

function NixvimManagerUtils.log(level, ...)
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

function NixvimManagerUtils.nix_access_tokens()
  local GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
  local has_token = GITHUB_TOKEN ~= nil
  NixvimManagerUtils.log("DEBUG", "nix_access_tokens: token_present=" .. tostring(has_token))
  if not GITHUB_TOKEN then
    return nil
  end
  return string.format("github.com=%s", GITHUB_TOKEN)
end

function NixvimManagerUtils.read_local_file(name)
  local src = debug.getinfo(1, "S").source
  NixvimManagerUtils.log("DEBUG", "read_local_file: name=" .. name .. " source=" .. tostring(src))
  if src:sub(1, 1) == "@" then
    local dir = src:sub(2):match("(.+)/[^/]+$")
    if dir then
      local f = io.open(dir .. "/" .. name, "r")
      if f then
        local content = f:read("*a")
        f:close()
        NixvimManagerUtils.log("DEBUG", "read_local_file: success name=" .. name)
        return content
      end
    end
  end
  NixvimManagerUtils.log("DEBUG", "read_local_file: not_found name=" .. name)
end

---Format the entire flake (best-effort, non-fatal).
---@param flake_dir string
function NixvimManagerUtils.nix_fmt(flake_dir)
  local cmd = { "nix", "fmt", flake_dir }

  local tokens = NixvimManagerUtils.nix_access_tokens()
  if tokens then
    table.insert(cmd, "--option")
    table.insert(cmd, "access-tokens")
    table.insert(cmd, tokens)
  end

  NixvimManagerUtils.log("DEBUG", "nix_fmt: flake_dir=" .. flake_dir .. " cmd=" .. vim.inspect(cmd))
  vim.system(cmd, { text = true, cwd = flake_dir }, function(r)
    NixvimManagerUtils.log("DEBUG", "nix_fmt: flake_dir=" .. flake_dir .. " exit_code=" .. r.code)
  end)
end

---@param cmd string[]
---@param cb fun(err: string|nil, stdout: string|nil)
function NixvimManagerUtils.run_async(cmd, cb)
  NixvimManagerUtils.log("DEBUG", "run_async: cmd=" .. vim.inspect(cmd))
  vim.system(cmd, { text = true }, function(r)
    if r.code ~= 0 then
      local err_msg = r.stderr ~= "" and r.stderr or r.stdout
      NixvimManagerUtils.log(
        "WARN",
        "run_async: error cmd=" .. vim.inspect(cmd) .. " err=" .. err_msg
      )
      cb(err_msg, nil)
    else
      NixvimManagerUtils.log("DEBUG", "run_async: success cmd=" .. vim.inspect(cmd))
      cb(nil, r.stdout or "")
    end
  end)
end

---@param cb fun(err: string|nil, store_path: string|nil, link)
---@param flake_dir string
---@param attr? string
---@param out_link? string
function NixvimManagerUtils.nix_build(cb, flake_dir, attr, out_link)
  local cmd = {
    "nix",
    "build",
    "--print-out-paths",
    string.format("%s#\"%s\"", DEV and "path:." or flake_dir, attr or "default"),
  }

  if DEV then
    table.insert(cmd, "--impure")
  end

  local tokens = NixvimManagerUtils.nix_access_tokens()
  if tokens then
    table.insert(cmd, "--option")
    table.insert(cmd, "access-tokens")
    table.insert(cmd, tokens)
  end

  NixvimManagerUtils.log(
    "DEBUG",
    "nix_build: flake_dir="
      .. flake_dir
      .. " attr="
      .. (attr or "N/A")
      .. " out_link="
      .. tostring(out_link)
      .. " cmd="
      .. table.concat(cmd, " ")
  )

  vim.system(cmd, { text = true, cwd = flake_dir }, function(r)
    if r.code ~= 0 then
      local err_msg = r.stderr ~= "" and r.stderr or r.stdout

      NixvimManagerUtils.log(
        "WARN",
        "nix_build: error flake_dir="
          .. flake_dir
          .. " attr="
          .. (attr or "N/A")
          .. " err="
          .. err_msg
      )

      return cb(err_msg)
    end

    local path = (r.stdout or ""):match("^%s*(/[%S]+)%s*$")
    if path then
      NixvimManagerUtils.log(
        "DEBUG",
        "nix_build: success flake_dir="
          .. flake_dir
          .. " attr="
          .. (attr or "N/A")
          .. " store_path="
          .. path
      )

      -- TODO: Link path
      cb(nil, path, out_link or string.format("%s/bin/nvim", path))
    else
      local err_msg = "unexpected nix build output: " .. tostring(r.stdout)
      NixvimManagerUtils.log(
        "WARN",
        "nix_build: error flake_dir=" .. flake_dir .. " attr=" .. attr .. " err=" .. err_msg
      )

      cb(err_msg)
    end
  end)
end

function NixvimManagerUtils.normalize(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

return NixvimManagerUtils
