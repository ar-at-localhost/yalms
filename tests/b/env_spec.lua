local env = require("yalms.env")
local helpers = require("helpers")

describe("yalms.env", function()
  describe("is_vim", function()
    it("detects vim environment", function()
      local result = env.is_vim()
      assert.is_boolean(result)
    end)
  end)

  describe("is_wezterm", function()
    it("detects wezterm environment", function()
      local result = env.is_wezterm()
      assert.is_boolean(result)
    end)
  end)

  describe("get_env", function()
    it("gets env var in vim mode", function()
      helpers.mock_vim()
      _G.vim.fn.getenv = function(name)
        if name == "HOME" then
          return "/home/test"
        end
        return nil
      end
      local val = env.get_env("HOME")
      assert.equal("/home/test", val)
      helpers.unmock_vim()
    end)

    it("gets env var in wezterm mode", function()
      helpers.unmock_vim()
      helpers.mock_wezterm()
      -- is_wezterm uses pcall(require("wezterm")) so we need to stub package.loaded
      package.preload["wezterm"] = function()
        return { json_encode = function() end, json_parse = function() end }
      end
      local val = env.get_env("HOME")
      package.preload["wezterm"] = nil
      helpers.unmock_wezterm()
      assert.is_string(val)
    end)

    it("returns nil when neither vim nor wezterm", function()
      helpers.unmock_vim()
      helpers.unmock_wezterm()
      -- In test environment without vim/wezterm, get_env returns nil
      -- because it only checks vim.fn.getenv or os.getenv when in those modes
      local val = env.get_env("NONEXISTENT_VAR_12345")
      assert.is_nil(val)
    end)
  end)

  describe("ensure_nvim", function()
    it("succeeds in vim mode", function()
      helpers.mock_vim()
      local ok = pcall(env.ensure_nvim, "test")
      assert.is_true(ok)
      helpers.unmock_vim()
    end)

    it("fails outside vim", function()
      helpers.unmock_vim()
      local ok, err = pcall(env.ensure_nvim, "test")
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)
  end)
end)
