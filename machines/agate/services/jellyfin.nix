{ config, pkgs, ... }:
let
  cfg = config.services.jellyfin;
in
{
  services.jellyfin.enable = true;

  systemd.services.jellyfin.serviceConfig = {
    BindReadOnlyPaths = [
      "/storage/media:${cfg.dataDir}/media"
    ];
  };

  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];
  services.caddy.virtualHosts."https://agate.coho-tet.ts.net:8920".extraConfig = ''
    reverse_proxy 127.0.0.1:8096
  '';

  users.users.jellyfin.extraGroups = [ "render" ];
  users.groups.media.members = [ cfg.user ];
}
