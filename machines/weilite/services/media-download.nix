{ config, pkgs, ... }:
let
  inherit (config.my-lib.settings)
    internalDomain
    ;
in
{
  sops.secrets = {
    "sonarr/api-key" = { };
    "radarr/api-key" = { };
  };
  services.jackett = {
    enable = true;
    openFirewall = false;
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
    listenAddress = "weilite.${internalDomain}";
    port = 21560;
  };

  services.prometheus.exporters.exportarr-radarr = {
    enable = true;
    url = "http://127.0.0.1:7878";
    apiKeyFile = config.sops.secrets."radarr/api-key".path;
    listenAddress = "weilite.${internalDomain}";
    port = 21561;
  };

  users.groups.media.members = [
    config.services.sonarr.user
    config.services.radarr.user
  ];
}
