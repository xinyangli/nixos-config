{ config, ... }:
{
  services.restic.server = {
    enable = true;
    dataDir = "/var/lib/restic";
    listenAddress = "127.0.0.1:19573";
    privateRepos = "true";
    extraFlags = [
      "--append-only"
    ];
  };

  networking.allowedTCPPorts = [ 8443 ];

  services.caddy.virtualHosts."https://backup.xinyang.life:8443".extraConfig = ''
    reverse_proxy ${config.services.restic.server.listenAddress}
  '';
}
