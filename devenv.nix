{
  config,
  pkgs,
  inputs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (inputs) nixvim np;
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv) system;
  };

  wezterm-types = import ./nix/wezterm.nix {inherit pkgs;};
  plugin-plenary = pkgs.vimPlugins.plenary-nvim;
  plugin-snacks = pkgs.vimPlugins.snacks-nvim;
  plugin-orgmode = pkgs.vimPlugins.orgmode;
  nvim = import ./nix/nixvim.nix {inherit system pkgs pkgs-unstable nixvim np;};

  tests = import ./nix/tests.nix {
    inherit pkgs;
    plugins = [plugin-plenary plugin-snacks plugin-orgmode];
  };
in {
  cachix.enable = false;

  env = {
    nvim = "";
    NVIM_PLENARY_LIB = "${plugin-plenary}/lua";
    NVIM_SNACKS_LUA_TYPES = "${plugin-snacks}/lua";
    NVIM_ORGMODE_LUA_TYPES = "${plugin-orgmode}/lua";
    WEZTERM_LUA_TYPES = "${wezterm-types}/share/lua/5.4";
    GITHUB_TOKEN = null;
  };

  packages = with pkgs;
    [
      stylua
      alejandra
      luarocks
      lua
      lua-language-server
      luaPackages.busted
      luaPackages.dkjson
      tests.tests
      tests.btest
      tests.ptest
      tests.ptestf
    ]
    ++ (
      if config.env.nvim == "TRUE"
      then [nvim]
      else []
    );

  git-hooks = {
    hooks = {
      alejandra.enable = true;
      stylua.enable = true;
    };
  };

  enterShell = ''
    export YALMS_DEV=true
    export CWD="$PWD"
    export LUA_PATH="$PWD/lua/?.lua;$PWD/lua/?/init.lua;;$PWD/lua/?/?.lua;''${LUA_PATH:-;;}"
    echo "yalms development environment"
  '';

  enterTest = "${tests.tests-text}";
}
