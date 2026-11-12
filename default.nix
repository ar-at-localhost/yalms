{
  lib,
  pkgs,
  ...
}: let
  inherit ((import ./version.nix)) version;
  root = ./.;
in
  pkgs.lua5_1.pkgs.buildLuarocksPackage {
    pname = "yalms";
    inherit version;
    knownRockspec = ./yalms-0.0.1-1.rockspec;

    src = lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.unions [
        (root + "/lua")
        (root + "/yalms-0.0.1-1.rockspec")
      ];
    };
  }
