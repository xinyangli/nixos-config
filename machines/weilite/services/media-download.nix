{ pkgs, ... }:
{
  services.jackett = {
    enable = true;
    package = pkgs.jackett.overrideAttrs {
      src = pkgs.fetchFromGitHub {
        owner = "jackett";
        repo = "jackett";
        rev = "v0.22.998";
        hash = "sha256-CZvgDWxxIAOTkodgmFNuT3VDW6Ln4Mz+Ki7m91f0BgE=";
      };
    };
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
}
