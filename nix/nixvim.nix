{
  system,
  pkgs,
  nixvim,
  np,
  ...
}: (nixvim.legacyPackages.${system}.makeNixvimWithModule {
  inherit pkgs;

  module = {lib, ...}: {
    imports = [
      np.nixvimModules.base
      np.nixvimModules.xtras.orgmode
    ];

    extraConfigLuaPost = let
      nvm-config = {
        dir.__raw = ''
          (function()
            return string.format("%s/.nvim/nvm", os.getenv("CWD"))
          end)()
        '';

        nixvims = {
          a = {
            name = "A";
            dirs = ["/tmp/a" "/tmp/aa"];
            initial_content = ''
              {
                opts.number = true;
              }
            '';
          };

          b = {
            name = "B";
            dirs = ["/tmp/B" "/tmp/aa" "/tmp/ba"];
            initial_content = ''
              {
                opts.relativenumber = true;
              }
            '';
          };
        };
      };

      nvm-config-lua = lib.nixvim.lua.toLuaObject nvm-config;
    in ''
      require('yalms.nvm').setup(${nvm-config-lua})
    '';
  };

  extraSpecialArgs = {
    inherit (pkgs) stdenv;
    inherit np;
  };
})
