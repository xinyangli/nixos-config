{ config, pkgs, ... }:
{
  services.jellyfin.enable = true;

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
}
