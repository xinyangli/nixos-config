{ config, pkgs, ... }:
let
  cfg = config.services.jellyfin;
in
{
  services.jellyfin.enable = true;

  systemd.services.jellyfin.serviceConfig = {
    BindReadOnlyPaths = [
      "/mnt/nixos/media:${cfg.dataDir}/media"
    ];
  };

  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];
  services.caddy.virtualHosts."https://weilite.coho-tet.ts.net:8920".extraConfig = ''
    reverse_proxy 127.0.0.1:8096
  '';
  networking.firewall.allowedTCPPorts = [ 8920 ]; # allow on lan
  users.users.jellyfin.extraGroups = [ "render" ];
  users.groups.media.members = [ cfg.user ];
}
