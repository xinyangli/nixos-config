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

    (nemo-with-extensions.override {
      extensions = [
        nemo-python
        nemo-fileroller
        owncloud-client
        owncloud-nautilus
        owncloud-shell-resources
      ];
    })

  ];

  dconf.settings = {
    "org/cinnamon/desktop/applications/terminal" =
      let
        script = (
          pkgs.writeShellScript "nemo-open-terminal" ''
            if ! zellij run --stacked --close-on-exit -- $SHELL; then
                foot
            fi
          ''
        );
      in
      {
        exec = "${script}";
      };
  };

  services.spotifyd = {
    enable = true;
    settings = {
      global = {
        no_audio_cache = false;
        bitrate = 320;
      };
    };
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
