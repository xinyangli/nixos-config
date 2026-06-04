{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.transmission;
  inherit (config.my-lib.settings) transmissionExporterUrl;
in
{
  sops.secrets = {
    "transmission/rpc-password" = { };
  };

  sops.templates."transmission-cred.json" = {
    content = builtins.toJSON {
      rpc-password = config.sops.placeholder."transmission/rpc-password";
    };
  };

  sops.templates."transmission-cred.env" = {
    content = ''
      TRANSMISSION_PASSWORD=${config.sops.placeholder."transmission/rpc-password"}
    '';
  };

  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    openPeerPorts = true;
    credentialsFile = config.sops.templates."transmission-cred.json".path;
    settings = {
      download-dir = "/storage/media";
      incomplete-dir = "/storage/transmission/incomplete";
      alt-speed-down = 40960;
      alt-speed-enabled = true;
      alt-speed-time-begin = 60;
      alt-speed-time-day = 127;
      alt-speed-time-enabled = true;
      alt-speed-time-end = 420;
      alt-speed-up = 4096;
      bind-address-ipv4 = "0.0.0.0";
      bind-address-ipv6 = "::";
      download-queue-enabled = true;
      download-queue-size = 10;
      incomplete-dir-enabled = true;
      lpd-enabled = false;
      message-level = 4;
      peer-congestion-algorithm = "";
      peer-id-ttl-hours = 6;
      peer-limit-global = 200;
      peer-limit-per-torrent = 50;
      peer-port = 51413;
      peer-socket-tos = "cs1";
      pex-enabled = true;
      preallocation = 1;
      prefetch-enabled = true;
      queue-stalled-enabled = true;
      queue-stalled-minutes = 30;
      rename-partial-files = true;
      rpc-bind-address = "127.0.0.1";
      rpc-enabled = true;
      rpc-authentication-required = true;
      rpc-port = 9092;
      rpc-username = "xin";
      rpc-whitelist = "127.0.0.1";
      speed-limit-down = 20480;
      speed-limit-down-enabled = true;
      speed-limit-up = 3072;
      speed-limit-up-enabled = true;
      start-added-torrents = true;
      watch-dir-enabled = false;
    };
  };

  networking.firewall.allowedTCPPorts = [
    9091
    51413
  ];
  services.caddy.virtualHosts."https://agate.coho-tet.ts.net:9091".extraConfig = ''
    reverse_proxy 127.0.0.1:${toString cfg.settings.rpc-port}
  '';

  services.caddy.virtualHosts."transmission.u.xiny.li".extraConfig = ''
    bind ${config.custom.mesh-network.caddy.fdRefs."443"}
    tls {
      dns desec {
        token {env.DESEC_TOKEN}
      }
    }
    reverse_proxy 127.0.0.1:${toString cfg.settings.rpc-port}
  '';

  systemd.tmpfiles.settings."10-media-storage" = {
    "/storage/media" = {
      d = {
        group = "media";
        mode = "0770";
        user = cfg.user;
      };
    };
    "/storage/transmission/incomplete" = {
      d = {
        group = cfg.group;
        mode = "0700";
        user = cfg.user;
      };
    };
  };

  users.groups.media.members = [ cfg.user ];
}
