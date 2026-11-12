{pkgs, ...}: let
  inherit (import ./version.nix) version;

  src = pkgs.lib.cleanSourceWith {
    src = ./.;
  };
in
  pkgs.vimUtils.buildVimPlugin {
    pname = "yalms";
    inherit version src;
    dependencies = [];
    doCheck = false;
  }
