{ config, lib, ... }:
{
  services.rustical = {
    enable = true;
    settings = {
    };
  };

  services.caddy.virtualHosts."derper01.xiny.li:8443".extraConfig = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
    }
    reverse_proxy 127.0.0.1:${toString config.services.tailscale.derper.port}
  '';
}
