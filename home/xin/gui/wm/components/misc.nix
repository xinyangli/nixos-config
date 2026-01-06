{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
  loginctl = "${pkgs.systemd}/bin/loginctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  brightnessctl = "${getExe pkgs.brightnessctl}";
  niri = "${getExe pkgs.niri}";
  playerPauseCmd = "${playerctl} --all-players pause";
  lockCmd = "${getExe config.custom-hm.gui.gtklock.package} --daemonize";
in
{
  services = {
    swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 60;
          command = "${brightnessctl} -s set 2";
          resumeCommand = "${brightnessctl} -r";
        }
        {
          timeout = 300;
          command = ''${niri} msg action power-off-monitors; ${loginctl} lock-session'';
        }
        {
          # Sleep if on battery
          timeout = 400;
          command = ''[ $(${pkgs.coreutils}/bin/cat /sys/class/power_supply/AC0/online) -eq 0 ] && ${systemctl} suspend-then-hibernate'';
        }
      ];
      events = [
        {
          event = "before-sleep";
          command = lib.concatStringsSep ";" [
            playerPauseCmd
            lockCmd
          ];
        }
        {
          event = "after-resume";
          # Avoid dark lock screen when we enter sleep after a timeout.
          command = "${brightnessctl} -r";
        }
        {
          event = "lock";
          command = lib.concatStringsSep ";" [
            lockCmd
          ];
        }
      ];
    };
  };
  systemd.user.services.swayidle.Unit.After = [ "graphical-session.target" ];

  services.swaync = {
    enable = true;
  };

  home.packages = [
    # gtklock-playerctl-module use tls in libsoup to fetch album cover,
    # and this is runtime dependency for libsoup if you want to use tls
    # https://github.com/NixOS/nixpkgs/blob/f61125a668a320878494449750330ca58b78c557/pkgs/development/libraries/libsoup/3.x.nix#L73
    pkgs.glib-networking
  ];
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
      modules = [
        "${pkgs.gtklock-playerctl-module}/lib/gtklock/playerctl-module.so"
      ];
      gtk-theme = "Catppuccin-GTK-Peach-Dark";
    };
  };
}
