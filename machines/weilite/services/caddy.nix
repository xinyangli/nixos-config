{ config, pkgs, ... }:
{
  sops = {
    secrets = {
      "caddy/cf_dns_token" = {
        owner = "caddy";
        mode = "400";
      };
      "caddy/dnspod_dns_token" = {
        owner = "caddy";
        mode = "400";
      };
    };
    templates."caddy.env".content = ''
      CF_API_TOKEN=${config.sops.placeholder."caddy/cf_dns_token"}
      DNSPOD_API_TOKEN=${config.sops.placeholder."caddy/dnspod_dns_token"}
    '';
  };

  services.caddy =
    let
      acmeCF = "tls {
        dns cloudflare {env.CF_API_TOKEN}
      }";
      acmeDnspod = "tls {
        dns dnspod {env.DNSPOD_API_TOKEN}
      }";
    in
    {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.0.0-20240703190432-89f16b99c18e"
          "github.com/caddy-dns/dnspod@v0.0.4"
        ];
        hash = "sha256-9DZ58u/Y17njwQKvCZNys8DrCoRNsHQSBD2hV2cm8uU=";
      };
      virtualHosts."derper00.namely.icu:8443".extraConfig = ''
        ${acmeDnspod}
        reverse_proxy 127.0.0.1:${toString config.services.tailscale.derper.port}
      '';
      # API Token must be added in systemd environment file
      virtualHosts."immich.xinyang.life:8000".extraConfig = ''
        ${acmeDnspod}
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
      virtualHosts."immich.xiny.li:8443".extraConfig = ''
        ${acmeCF}
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
    };

  networking.firewall.allowedTCPPorts = [
    8000
    8443
  ];

  systemd.services.caddy = {
    serviceConfig = {
      EnvironmentFile = config.sops.templates."caddy.env".path;
    };
  };
}
