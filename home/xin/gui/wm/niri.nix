{
  config,
  pkgs,
  lib,
  ...
}:
let
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
    ./components/background.nix
    ./components/fuzzel.nix
    ./components/misc.nix
    ./components/waybar.nix
  ];

  config = {
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

    home.packages = with pkgs; [
      wl-clipboard
    ];

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
