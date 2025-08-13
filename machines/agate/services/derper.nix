{ config, lib, ... }:
{
  services.tailscale.derper = {
    enable = true;
    domain = "derper01.xiny.li";
    openFirewall = true;
    verifyClients = true;
  };

  services.caddy.virtualHosts."derper01.xiny.li:8443".extraConfig = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
    }
    reverse_proxy 127.0.0.1:${toString config.services.tailscale.derper.port}
  '';
  # tailscale derper module use nginx for reverse proxy
  services.nginx.enable = lib.mkForce false;
}
