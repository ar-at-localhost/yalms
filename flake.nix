{
  description = "yalms <Yet another set of lua modules>";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };

        yalms = import ./nix/yalms.nix {inherit pkgs;};
      in {
        formatter = pkgs.alejandra;
        packages.default = yalms;
      }
    );
}
