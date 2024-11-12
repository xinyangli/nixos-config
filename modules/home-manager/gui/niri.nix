{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.custom-hm.gui.niri;
  wallpaper = pkgs.fetchurl {
    url = "https://github.com/NixOS/nixos-artwork/blob/master/wallpapers/nixos-wallpaper-catppuccin-mocha.png?raw=true";
    hash = "sha256-fmKFYw2gYAYFjOv4lr8IkXPtZfE1+88yKQ4vjEcax1s=";
  };
in
{
  options.custom-hm.gui.niri = {
    enable = mkEnableOption "niri";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      xwayland-satellite
      cosmic-files
    ];
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
      gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    };
    services.network-manager-applet.enable = true;

    systemd.user.services.swaybg = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
      Unit = {
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.swaybg} -i ${wallpaper} -m fill";
        Restart = "on-failure";
      };
    };

    programs.swaylock = {
      enable = true;
      settings = {
        show-failed-attempts = true;
        daemonize = true;
        scaling = "fill";
      };
    };

    systemd.user.services.swayidle.Unit.After = [ "graphical-session.target" ];

    services = {
      swayidle = {
        enable = true;
        timeouts = [
          {
            timeout = 900;
            command = "/run/current-system/systemd/bin/systemctl suspend";
          }
        ];
        events = [
          {
            event = "lock";
            command = "${pkgs.swaylock}/bin/swaylock";
          }
          {
            event = "before-sleep";
            command = "/run/current-system/systemd/bin/loginctl lock-session";
          }
        ];
      };
    };
  };
}
