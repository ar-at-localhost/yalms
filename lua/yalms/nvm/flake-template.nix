{
  description = "Nixvim manager flake";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    np = {
      url = "github:ar-at-localhost/np/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs: let
    flakeUtils = inputs.flake-utils;
  in
    flakeUtils.lib.eachDefaultSystem (
      system: let
        pkgs = import inputs.nixpkgs {
          inherit system;
        };
        inherit (inputs) nixvim;
        inherit (inputs) np;

        base = nixvim.legacyPackages.${system}.makeNixvimWithModule {
          inherit pkgs;
          module = {
            imports = [
              np.nixvimModules.base
              np.nixvimModules.xtras.orgmode
            ];
          };
          extraSpecialArgs = {
            inherit np nixvim;
            inherit (pkgs) stdenv;
          };
        };

        json = builtins.readFile ./config.json;
        config = builtins.fromJSON json;

        baseNames = config.bases or [];
        configured-bases =
          builtins.mapAttrs (
            name: _: (import (./. + "/_${name}.nix") {
              inherit system pkgs nixvim np;
              bases =
                configured-bases
                // {
                  default =
                    if builtins.hasAttr "default" configured-bases
                    then configured-bases.default
                    else base;
                };
            })
          )
          (builtins.listToAttrs (map (n: {
              name = n;
              value = true;
            })
            baseNames));

        bases =
          configured-bases
          // (
            if builtins.hasAttr "default" configured-bases
            then {}
            else {default = base;}
          );

        modulePackages =
          builtins.mapAttrs (
            key: entry: let
              imported = import (./. + "/${key}/nixvim.nix");
              isLambda = builtins.isFunction imported;
              baseToUse =
                if builtins.hasAttr "base" entry
                then bases.${entry.base}
                else null;
            in
              if isLambda
              then
                imported {
                  inherit system pkgs nixvim np bases;
                }
              else
                baseToUse.extend {
                  imports = [imported];
                }
          )
          (config.nixvims or {});
      in {
        formatter = pkgs.alejandra;
        packages =
          {inherit (bases) default;}
          // modulePackages;
        devShells.default = pkgs.mkShell {
          name = "";
          packages = with pkgs; [alejandra];
        };
      }
    );
}
