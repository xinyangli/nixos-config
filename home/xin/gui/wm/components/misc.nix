{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
in
{
  services = {
    swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 60;
          command = "${getExe pkgs.brightnessctl} -s set 2";
          resumeCommand = "${getExe pkgs.brightnessctl} -r";
        }
        {
          timeout = 300;
          command = ''${getExe pkgs.niri} msg action power-off-monitors'';
        }
        {
          # Sleep if on battery
          timeout = 300;
          command = ''[ $(${pkgs.coreutils}/bin/cat /sys/class/power_supply/AC0/online) -eq 0 ] && /run/current-system/systemd/bin/systemctl suspend-then-hibernate'';
        }
      ];
      events = [
        {
          event = "before-sleep";
          command = "${pkgs.playerctl}/bin/playerctl --all-players pause; ${config.custom-hm.gui.gtklock.package} --daemonize";
        }
        {
          event = "after-resume";
          # Avoid dark lock screen when we enter sleep after a timeout.
          command = "${getExe pkgs.brightnessctl} -r";
        }
      ];
    };
  };
  systemd.user.services.swayidle.Unit.After = [ "graphical-session.target" ];

  services.swaync = {
    enable = true;
  };

  custom-hm.gui.gtklock = {
    enable = true;
    package = pkgs.gtklock.overrideAttrs {
      patches = [
        # TODO: https://github.com/jovanlanik/gtklock/pull/139
        (pkgs.fetchurl {
          url = "https://github.com/jovanlanik/gtklock/commit/99532b665cf4dcccde3f5eadf14c50438626e01d.diff";
          hash = "sha256-bJaFPXzW/yGM1TFisXRoKuMYcFnf0hMSOZEmt2P1cnw=";
        })
      ];
    };
    config = {
      # gtk-theme = "Catppuccin-GTK-Dark";
    };
  };
}
