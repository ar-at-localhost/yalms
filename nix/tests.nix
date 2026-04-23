{
  pkgs,
  plugins ? [],
}: let
  init = pkgs.writeText "minimal_init.lua" ''
    vim.opt.swapfile = false
    vim.opt.backup   = false
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    ${builtins.concatStringsSep "\n" (map (p: ''vim.opt.runtimepath:prepend("${p}")'') plugins)}
    vim.cmd("runtime! plugin/**/*.lua")
    vim.cmd("runtime! plugin/**/*.vim")
  '';

  clean = ''
    set -euo pipefail
    export HOME=$(mktemp -d)
    export XDG_CONFIG_HOME=$HOME/.config
    export XDG_DATA_HOME=$HOME/.local/share
    export XDG_STATE_HOME=$HOME/.local/state
    export XDG_CACHE_HOME=$HOME/.cache
  '';

  nvim = ''
    ${clean}
    exec ${pkgs.neovim}/bin/nvim --headless -u ${init} \
      -c "set rtp+=." \
      -c "runtime plugin/plenary.vim"'';

  nlua = pkgs.writeShellScriptBin "nlua" ''
    ${nvim} \
      -l "$@"
  '';

  btest = pkgs.writeShellScriptBin "btest" ''
    exec ${pkgs.lua51Packages.busted}/bin/busted \
      --lua=${nlua}/bin/nlua \
      --output=utfTerminal \
      "''${@:-tests/b}"
  '';

  ptest = pkgs.writeShellScriptBin "ptest" ''
    ${nvim} \
      -c "PlenaryBustedDirectory ./tests/p { timeout = 5 * 60 * 1000 }" \
      -c "qa!"
  '';
in {
  inherit btest ptest;
  tests = pkgs.writeShellScriptBin "tests" ''
    set -e

    bash ${btest}/bin/btest "$@"
    bash ${ptest}/bin/ptest
  '';
}
