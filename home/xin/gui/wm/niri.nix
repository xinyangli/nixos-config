{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.my-lib) flakePath;
  configDir = "${flakePath config}/config";
in
{
  imports = [
    ./components/background.nix
    ./components/vicinae.nix
    ./components/misc.nix
    ./components/waybar.nix
  ];

  config = {
    xdg.configFile = {
      niri.source = config.lib.file.mkOutOfStoreSymlink "${configDir}/niri";
    };

    home.packages = with pkgs; [
      wl-clipboard
      xwayland-satellite # managed by niri
    ];

    custom-hm.gui.polkit = "pantheon";
    custom-hm.gui.gtklock = {
      enable = true;
      config = {
        # gtk-theme = "Catppuccin-GTK-Dark";
      };
    };

  };
}
