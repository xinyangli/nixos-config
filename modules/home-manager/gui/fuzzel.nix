{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.custom-hm.gui.fuzzel;
in
{
  options.custom-hm.gui.fuzzel = {
    enable = mkEnableOption "fuzzel";
  };

  config = mkIf cfg.enable {
    programs.fuzzel.enable = true;
  };
}
