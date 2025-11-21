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

    # == Theme ==
    home.pointerCursor = {
      name = "Bibata-Modern-Ice";
      size = 24;
      package = pkgs.bibata-cursors;
      gtk.enable = true;
    };
    gtk = {
      enable = true;
      theme = {
        name = "Catppuccin-GTK-Dark";
        package = pkgs.magnetic-catppuccin-gtk;
      };
      iconTheme = {
        name = lib.mkForce "Qogir";
        package = lib.mkForce pkgs.qogir-icon-theme;
      };
      gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
    qt = {
      enable = true;
      style.name = "kvantum";
      platformTheme.name = "kvantum";
    };
    # == == ==
  };
}
