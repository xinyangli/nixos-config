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

    owncloud-client
    owncloud-nautilus
    owncloud-shell-resources
  ];

  # TODO: Waiting for a new release of librespot, see github: spotifyd #1299
  services.spotifyd = {
    enable = true;
    package = pkgs.spotifyd.overrideAttrs (
      finalAttrs: prevAttrs: {
        version = "0.4.2";
        src = pkgs.fetchFromGitHub {
          owner = "Spotifyd";
          repo = "spotifyd";
          tag = "v0.4.2";
          hash = "sha256-+t6z2cenw0fU5onl5F5vtk7Hr24IzTCAee+Lcnd7aT4=";
        };
        cargoDeps = prevAttrs.cargoDeps.overrideAttrs (prevAttrs: {
          vendorStaging = prevAttrs.vendorStaging.overrideAttrs {
            inherit (finalAttrs) src version;
            outputHash = "sha256-rv4FWyciv6vDKtD7moJppY3tOJb0B3ezE9HgCLNhIo8=";
          };
        });
      }
    );
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
