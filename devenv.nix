{
  lib,
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
  nvim = import ./nix/nixvim.nix {inherit system pkgs pkgs-unstable nixvim np;};
in {
  cachix.enable = lib.mkDefault false;

  packages = with pkgs; [
    stylua
    alejandra
    luarocks
    lua
    lua-language-server
    luaPackages.busted
    luaPackages.dkjson
    nvim
  ];

  env = {
    WEZTERM_LUA_TYPES = "${wezterm-types}/share/lua/5.4";
    NVIM_PLENARY_LIB = "${pkgs.vimPlugins.plenary-nvim}/lua";
    LUA_PATH = "./lua/?.lua;./lua/?/init.lua;;";
  };

  git-hooks = {
    hooks = {
      alejandra.enable = true;
      stylua.enable = true;
    };
  };

  enterShell = ''
    echo "yalms development environment"
  '';

  enterTest = ''
    busted tests/
  '';
}
