# These applications have larger closure size and is not always necessary
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    resources
    remmina
    qq
    wechat
    wpsoffice-cn
    ttf-wps-fonts

    gnome-sound-recorder

    eudic
    calibre

    # Multimedia
    obs-studio
    piliplus

    # Browser
    chromium

    # wemeet
    wemeet

    nautilus-open-any-terminal

    owncloud-client
    owncloud-nautilus
    owncloud-shell-resources
  ];

  dconf.settings = {
    "com/github/stunkymonkey/nautilus-open-any-terminal".terminal = "foot";
  };

  # Enable extension support for nautilus
  home.sessionVariables.NAUTILUS_4_EXTENSION_DIR = "${pkgs.nautilus-python}/lib/nautilus/extensions-4";

  # TODO: Waiting for a new release of librespot, see github: spotifyd #1299
  services.spotifyd = {
    enable = true;
  };

  systemd.user.services.owncloud = {
    Unit = {
      Description = "OwnCloud Client with Custom OAuth";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.owncloud-client}/bin/owncloud";
      Environment = [
        "OWNCLOUD_OAUTH_CLIENT_ID=owncloud"
        "OWNCLOUD_OAUTH_PORT=15241"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
