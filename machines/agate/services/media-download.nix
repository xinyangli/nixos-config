{ config, pkgs, ... }:
{
  sops.secrets = {
    "sonarr/api-key" = { };
    "radarr/api-key" = { };
  };
  services.jackett = {
    enable = true;
  };

  nixpkgs.config.permittedInsecurePackages = [
    "aspnetcore-runtime-6.0.36"
    "aspnetcore-runtime-wrapped-6.0.36"
    "dotnet-sdk-6.0.428"
    "dotnet-sdk-wrapped-6.0.428"
  ];

  services.sonarr = {
    enable = true;
  };

  services.radarr = {
    enable = true;
  };

  services.prometheus.exporters.exportarr-sonarr = {
    enable = true;
    url = "http://127.0.0.1:8989";
    apiKeyFile = config.sops.secrets."sonarr/api-key".path;
    listenAddress = "127.0.0.1";
    port = 21560;
  };

  services.prometheus.exporters.exportarr-radarr = {
    enable = true;
    url = "http://127.0.0.1:7878";
    apiKeyFile = config.sops.secrets."radarr/api-key".path;
    listenAddress = "127.0.0.1";
    port = 21561;
  };

  services.caddy.virtualHosts."http://agate.10118244.xyz:18080".extraConfig = ''
    handle_path /prometheus/sonarr/metrics {
      rewrite * /metrics
      reverse_proxy http://127.0.0.1:21560
    }
    handle_path /prometheus/radarr/metrics {
      rewrite * /metrics
      reverse_proxy http://127.0.0.1:21561
    }
  '';

  users.groups.media.members = [
    config.services.sonarr.user
    config.services.radarr.user
  ];
}
