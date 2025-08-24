{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption getExe;
  cfg = config.custom-hm.gui.niri;
  wallpaper = config.custom-hm.gui.wallpaper;
  xwayland-satellite = pkgs.xwayland-satellite.overrideAttrs (drv: rec {
    src = pkgs.fetchFromGitHub {
      owner = "Supreeeme";
      repo = "xwayland-satellite";
      rev = "3e6f892d20d918479e67d1e6c90c4be824a9d4ab";
      hash = "sha256-W1UUok7DPi4IXCYtc273FbVH1ifuCIcl+oO6CDqt8Dk=";
    };
    cargoDeps = drv.cargoDeps.overrideAttrs (
      lib.const {
        name = "xwayland-satellite-vendor.tar.gz";
        inherit src;
        outputHash = "sha256-/nK4cVgelaMtpym18RYNafPUFnMOG4uHRpVO8bOS3ow=";
      }
    );
  });
in
{
  imports = [
    ./themes.nix
  ];

  options.custom-hm.gui.niri = {
    enable = mkEnableOption "niri";
  };

  config = mkIf cfg.enable {
    systemd.user.services.xwayland-satellite = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
      Unit = {
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${xwayland-satellite}/bin/xwayland-satellite";
        Restart = "on-failure";
      };
    };

    home.sessionVariables.DISPLAY = ":0";

    services.swww.enable = true;
    systemd.user.services.bg-switch =
      let
        wallpaper_directory = config.home.homeDirectory + "/Pictures/Wallpapers";
        wallpaper_switch = pkgs.writeShellScript "wallpaper-switch" ''
          img=$(ls ${wallpaper_directory} | shuf | head -1)
          ${lib.getExe pkgs.swww} img ${wallpaper_directory}/$img
        '';
      in
      {
        Install = {
          WantedBy = [ config.wayland.systemd.target ];
        };
        Unit = {
          After = [ "swww.service" ];
        };
        Service = {
          ExecStart = "${wallpaper_switch}";
          Restart = "on-failure";
          RestartSec = "30s";
        };
      };
    systemd.user.timers.bg-switch = {
      Unit = {
        Description = "Switch wallpaper hourly";
      };
      Install = {
        WantedBy = [ config.wayland.systemd.target ];
      };
      Timer = {
        Unit = "bg-switch.service";
        OnCalendar = "hourly";
      };
    };

    services.swaync = {
      enable = true;
    };

    custom-hm.gui.gtklock = {
      enable = true;
      config = {
        gtk-theme = "Catppuccin-GTK-Dark";
      };
    };

    systemd.user.services.swayidle.Unit.After = [ "graphical-session.target" ];

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
            timeout = 500;
            command = ''[ $(${pkgs.coreutils}/bin/cat /sys/class/power_supply/AC0/online) -eq 0 ] && /run/current-system/systemd/bin/systemctl suspend-then-hibernate'';
          }
        ];
        events = [
          {
            event = "lock";
            command = "${getExe pkgs.gtklock}";
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
