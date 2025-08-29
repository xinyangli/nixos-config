{ config, pkgs, ... }:
{
  sops = {
    secrets = {
      "caddy/cf_dns_token" = {
        owner = "caddy";
        mode = "400";
      };
      "caddy/huawei_dns_access_key" = {
        owner = "caddy";
        mode = "400";
      };
      "caddy/huawei_dns_secret_key" = {
        owner = "caddy";
        mode = "400";
      };
    };
    templates."caddy.env".content = ''
      CF_API_TOKEN=${config.sops.placeholder."caddy/cf_dns_token"}
      HUAWEICLOUD_ACCESS_KEY=${config.sops.placeholder."caddy/huawei_dns_access_key"}
      HUAWEICLOUD_SECRET_KEY=${config.sops.placeholder."caddy/huawei_dns_secret_key"}
    '';
  };

  services.caddy =
    let
      acmeCF = "tls {
        dns cloudflare {env.CF_API_TOKEN}
      }";
      acmeHuawei = "tls {
        dns huaweicloud  {
          access_key_id {env.HUAWEICLOUD_ACCESS_KEY}
          secret_access_key {env.HUAWEICLOUD_SECRET_KEY}
        }
      }";
    in
    {
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.1"
        ];
        hash = "sha256-AcWko5513hO8I0lvbCLqVbM1eWegAhoM0J0qXoWL/vI=";
      };
      virtualHosts."derper00.namely.icu:8443".extraConfig = ''
        ${acmeCF}
        reverse_proxy 127.0.0.1:${toString config.services.tailscale.derper.port}
      '';
    };

  networking.firewall.allowedTCPPorts = [ 8443 ];

  systemd.services.caddy = {
    serviceConfig = {
      EnvironmentFile = config.sops.templates."caddy.env".path;
    };
  };
}
