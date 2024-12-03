{ config, ... }:
let
  mkPrune = user: host: {
    name = "${user}-${host}-prune";
    value = {
      user = "restic";
      repository = "/var/lib/restic/${user}/${host}";
      passwordFile = "/var/lib/restic/localpass";
      timerConfig = {
        OnCalendar = "02:05";
        RandomizedDelaySec = "1h";
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
      ];
    };

  };
in
{
  services.restic.server = {
    enable = true;
    dataDir = "/var/lib/restic";
    listenAddress = "127.0.0.1:19573";
    privateRepos = true;
    extraFlags = [
      "--append-only"
      "--prometheus-no-auth"
    ];
  };

  services.restic.backups = builtins.listToAttrs [
    (mkPrune "xin" "calcite")
    (mkPrune "xin" "massicot")
    (mkPrune "xin" "biotite")
    (mkPrune "xin" "thorite")
  ];

  networking.firewall.allowedTCPPorts = [ 8443 ];

  services.caddy.virtualHosts."https://backup.xinyang.life:8443".extraConfig = ''
    reverse_proxy ${config.services.restic.server.listenAddress}
  '';
}
