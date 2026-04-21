{pkgs, ...}: let
  wezterm-types-version = "1.4.0-1";
in
  pkgs.stdenv.mkDerivation {
    pname = "wezterm-types";
    version = wezterm-types-version;
    src = pkgs.fetchFromGitHub {
      owner = "DrKJeff16";
      repo = "wezterm-types";
      rev = "4179269";
      hash = "sha256-/lSPtDKCw5pju9363xdPlZIzS0Zo2NCdnkVniv17nA0=";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/lua/5.4
      cp -r lua/wezterm/types/. $out/share/lua/5.4/
    '';
  }
