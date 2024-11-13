{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption getExe;
  cfg = config.custom-hm.gui.niri;
  wallpaper = pkgs.fetchurl {
    url = "https://github.com/NixOS/nixos-artwork/blob/master/wallpapers/nixos-wallpaper-catppuccin-mocha.png?raw=true";
    hash = "sha256-fmKFYw2gYAYFjOv4lr8IkXPtZfE1+88yKQ4vjEcax1s=";
  };
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
    home.packages = with pkgs; [
      cosmic-files
    ];

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

    custom-hm.gui.gtklock = {
      enable = true;
      config = {
        gtk-theme = "Catppuccin-GTK-Dark";
        # style = pkgs.writeText "gtklock-style.css" ''
        #   window {
        #     background-size: cover;
        #     background-repeat: no-repeat;
        #     background-position: center;
        #   }
        # '';
        # modules = [
        #   "${pkgs.gtklock-playerctl-module}/lib/gtklock/playerctl-module.so"
        #   "${pkgs.gtklock-userinfo-module}/lib/gtklock/userinfo-module.so"
        # ];
      };
    };

    systemd.user.services.swayidle.Unit.After = [ "graphical-session.target" ];

    services = {
      swayidle = {
        enable = true;
        timeouts = [
          # {
          #   timeout = 300;
          #   command = "/run/
          # }
          {
            timeout = 900;
            command = "/run/current-system/systemd/bin/systemctl suspend";
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
