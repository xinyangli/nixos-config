{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.custom-hm.gui.fuzzel;
in
{
  options.custom-hm.gui.fuzzel = {
    enable = mkEnableOption "fuzzel";
  };

  config = mkIf cfg.enable {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          fields = "filename,name,exec,generic";
      	  y-margin = 30;
          width = 40;
          use-bold = true;
          line-height = 30;
        };
      };
    };
    home.packages = with pkgs; [
      networkmanager_dmenu
      networkmanagerapplet
    ];
    xdg.configFile."networkmanager-dmenu/config.ini".text = ''
      [dmenu]
      dmenu_command = fuzzel --dmenu
      wifi_chars = ▂▄▆█
      wifi_icons = 󰤯󰤟󰤢󰤥󰤨
    '';
  };
}
