{ config, pkgs, ... }:
{
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

  users.groups.media.members = [
    config.services.sonarr.user
    config.services.radarr.user
  ];
}
