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
      "niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink "${configDir}/niri/config.kdl";
      "niri/nixos_gen_config.kdl".text = ''
        screenshot-path "${config.home.homeDirectory}/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
      '';
    };

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      configPackages = [ pkgs.niri ];
    };

    home.packages = with pkgs; [
      wl-clipboard
      brightnessctl
      xwayland-satellite # managed by niri
    ];

    # custom-hm.gui.polkit = "pantheon";
  };
}
