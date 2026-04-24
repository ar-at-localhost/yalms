local a = require("plenary.async")
local async = require("plenary.async.tests")

-- ---------------------------------------------------------------------------
-- Unit tests: NixvimManager
-- ---------------------------------------------------------------------------

local debug = os.getenv("DEBUG")
local test_dir = "/tmp/nixvim-test"

if not debug then
  os.execute("rm -rf " .. test_dir)
end

local get_manager = a.wrap(function(opts, cb)
  NixvimManager = require("yalms.nvm.manager")
  local manager = NixvimManager:new(vim.tbl_extend("force", { dir = test_dir }, opts or {}, {
    initialTemplate = [[
{
  description = "Nixvim manager flake (test)";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    flakeUtils = inputs.flake-utils;
  in
    flakeUtils.lib.eachDefaultSystem (system: let
      pkgs = import inputs.nixpkgs {inherit system;};
      inherit (inputs) nixvim;

      json = builtins.readFile ./config.json;
      config = builtins.fromJSON json;

      default =
        if builtins.hasAttr "default" config.nixvims
        then (import (./. + "/${default}/nixvim.nix"))
        else
          nixvim.legacyPackages.${system}.makeNixvimWithModule {
            inherit pkgs;

            module = {
              opts.mouse = "";
            };

            extraSpecialArgs = {
              inherit nixvim;
              inherit (pkgs) stdenv;
            };
          };

      filterAttrs = attrs:
        builtins.removeAttrs attrs
        (builtins.filter (k: (builtins.substring 0 1 k == "_") || k == "default")
          (builtins.attrNames attrs));

      builds = let
        filtered =
          filterAttrs config.nixvims;
      in
        (builtins.mapAttrs (
            key: _: let
              imported = import (./. + "/${key}/nixvim.nix");
              isLambda = builtins.isFunction imported;
            in
              if isLambda
              then
                imported {
                  inherit system pkgs nixvim builds;
                }
              else
                default.extend {
                  imports = [imported];
                }
          )
          filtered)
        // {inherit default;};
    in {
      formatter = pkgs.alejandra;

      packages = builds;

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [alejandra];
      };
    });
}
]],
  }))

  manager:on("ready", function(m)
    if not m or m._error then
      return cb(m._error or "Something went wrong!")
    end

    cb(manager)
  end)
end, 2)

async.describe("nixvim", function()
  async.it("tests nixvim manager", function()
    local pre_added_link = "/tmp/pre-added-nvim"

    local manager = get_manager({
      nixvims = {
        ["pre-added"] = { initial_content = "{}", link = pre_added_link },
      },
    })

    assert.is_table(manager)
    assert.is_nil(manager._error)
    assert.is_same(manager:get_dir(), test_dir)
    local pre_added = manager.nixvims["pre-added"]
    assert.is_table(pre_added)
    assert.is_equal("pre-added", pre_added.name)
    assert.is_equal(pre_added_link, pre_added.link)

    local err, result = a.wrap(function(callback)
      manager:add({ name = "test-module", initial_content = "{}" }, callback)
    end, 1)()
    assert.is_nil(err)
    assert.is_table(result)

    local queue_before = #manager._queue
    local add_err, add_res = a.wrap(function(callback)
      manager:add(
        { name = "test-module-1", initial_content = "{}", dirs = { "/tmp/a", "/tmp/b" } },
        callback
      )
    end, 1)()

    assert.is_nil(add_err)
    assert.is_true(#manager._queue >= queue_before)
    assert.is_table(add_res.dirs)
    assert.is_equal("/tmp/a", add_res.dirs[1])
    assert.is_equal("/tmp/b", add_res.dirs[2])

    local remove_err, remove_res = a.wrap(function(callback)
      manager:remove("test-module", function(remove_err)
        callback(remove_err)
      end)
    end, 1)()

    assert.is_nil(remove_err)

    err = a.wrap(function(callback)
      manager:remove("nonexistent-module", callback)
    end, 1)()

    assert.is_truthy(err)

    local update_err, update_result = a.wrap(function(callback)
      manager:update({
        name = "test-module-1",
        initial_content = "{ opts.background = \"light\"; }",
        dirs = { "/tmp/c", "/tmp/d" },
      }, callback)
    end, 1)()
    assert.is_nil(update_err)
    assert.is_table(update_result)
    assert.is_table(update_result.dirs)

    local get_err, get_result = a.wrap(function(callback)
      manager:get("test-module-1", callback)
    end, 1)()
    assert.is_nil(get_err)
    assert.is_table(get_result)

    local link_res = manager:resolve_link("/tmp/c")
    assert.is_truthy(link_res)
    assert.is_same(link_res, add_res.link)

    local reload_err, _ = a.wrap(function(callback)
      manager:reload(callback)
    end, 0)()
    assert.is_nil(reload_err)
  end)
end)
