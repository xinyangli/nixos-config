{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.custom-hm.gui;
in
{
  imports = [
    ./niri.nix
    ./fuzzel.nix
    ./gtklock.nix
    ./waybar.nix
  ];

  options.custom-hm.gui = {
    wallpaper = mkOption {
      type = types.path;
      default = ./bwmountains.jpg;
    };
  };
}
