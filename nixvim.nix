# `yalms` Nixvim module
{lib, ...}:
lib.nixvim.plugins.mkNeovimPlugin {
  name = "yalms";
  maintainers = [];
  callSetup = false;
}
