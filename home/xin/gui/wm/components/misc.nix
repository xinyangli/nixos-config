{ pkgs, lib, ... }:
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
          command = "${pkgs.playerctl}/bin/playerctl --all-players pause; pgrep gktlock || ${getExe pkgs.gtklock} --daemonize";
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
    config = {
      # gtk-theme = "Catppuccin-GTK-Dark";
    };
  };
}
