{pkgs, ...}: let
  src = pkgs.lib.cleanSourceWith {
    src = ../.;
    filter = path: _: let
      rel = pkgs.lib.removePrefix (toString ../.) (toString path);
    in
      pkgs.lib.hasPrefix "/lua" rel || pkgs.lib.hasPrefix "/plugin" rel;
  };
in
  pkgs.vimUtils.buildVimPlugin {
    pname = "yalms";
    version = "unstable";
    inherit src;
  }
