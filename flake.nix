{
  description = "Yalms - Yet Another Set of Lua Modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = {self, ...} @ inputs: let
    inherit (inputs.nixpkgs) lib;

    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forEachSupportedSystem = f:
      lib.genAttrs supportedSystems (
        system:
          f {
            inherit self system;
            pkgs = import inputs.nixpkgs {
              inherit system;
            };
          }
      );

    mkOutputs = pkgs: {
      yalms = pkgs.callPackage ./default.nix {};

      vimPlugin =
        pkgs.callPackage ./vim-plugin.nix {};
    };
  in {
    checks = forEachSupportedSystem (
      {pkgs, ...}: mkOutputs pkgs
    );

    devShells = forEachSupportedSystem (
      {pkgs, ...}: {
        default = pkgs.mkShell {
          packages = with pkgs; [lux-cli lua51Packages.lux-lua alejandra markdownlint-cli2 oxfmt];
        };
      }
    );

    overlays.default = final: prev: (let
      outputs = mkOutputs prev;
    in {
      inherit (outputs) yalms;
      vimPlugins =
        prev.vimPlugins
        // {
          yalms = outputs.vimPlugin;
        };
    });

    packages = forEachSupportedSystem (
      {pkgs, ...}: mkOutputs pkgs
    );

    nixvimModules.yalms = ./nixvim.nix;
  };
}
