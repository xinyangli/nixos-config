{ config, pkgs, ... }:
let
  inherit (config.my-lib) serviceHarden;
  port = 1200;
in
{
  sops.secrets = {
    "rsshub/env/CAIXIN_COOKIE" = { };
  };
  sops.templates."caixin.env".content = ''
    CAIXIN_COOKIE=${config.sops.placeholder."rsshub/env/CAIXIN_COOKIE"}
  '';
  systemd.services.rsshub = {
    description = "RSSHub";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      PORT = toString port;
      LISTEN_INADDR_ANY = "0";
      CACHE_CONTENT_EXPIRE = "600";
    };

    serviceConfig = serviceHarden // {
      User = "rsshub";
      Group = "rsshub";

      EnvironmentFile = [ config.sops.templates."caixin.env".path ];
      ExecStart = "${pkgs.rsshub}/bin/rsshub";

      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
        "AF_NETLINK"
      ];

      MemoryDenyWriteExecute = false;
      Restart = "always";
      RestartSec = 5;
    };
  };

  users.users.rsshub = {
    group = "rsshub";
    isSystemUser = true;
  };
  users.groups.rsshub = { };

  services.caddy.virtualHosts."pek-0.rsshub.xiny.li:8443".extraConfig = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
    }
    abort not remote_ip 45.142.178.32
    reverse_proxy 127.0.0.1:${toString port}
  '';
}
