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

  xdg.configFile.qt5ct.source = config.lib.file.mkOutOfStoreSymlink "${configDir}/qt5ct";
  xdg.configFile.qt6ct.source = config.lib.file.mkOutOfStoreSymlink "${configDir}/qt6ct";
  qt = {
    enable = true;
    style.name = "kvantum";
    platformTheme = {
      name = "qtct";
    };
  };
  home.sessionVariables."QT_STYLE_OVERRIDE" = lib.mkForce "";
  # == == ==
}
