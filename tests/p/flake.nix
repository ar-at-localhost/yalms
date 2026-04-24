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
