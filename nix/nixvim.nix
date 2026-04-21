{
  system,
  pkgs,
  nixvim,
  np,
  ...
}: (nixvim.legacyPackages.${system}.makeNixvimWithModule {
  inherit pkgs;

  module = {
    extraPlugins = [(import ./yalms.nix {inherit pkgs;})];
    imports = [
      np.nixvimModules.base
      np.nixvimModules.xtras.orgmode
    ];
  };

  extraSpecialArgs = {
    inherit (pkgs) stdenv;
    inherit np;
  };
})
