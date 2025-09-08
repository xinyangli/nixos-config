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

  networking.firewall.allowedTCPPorts = [ 8443 ];

  services.caddy.package = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/cloudflare@v0.2.1"
    ];
    hash = "sha256-AcWko5513hO8I0lvbCLqVbM1eWegAhoM0J0qXoWL/vI=";
  };

  systemd.services.caddy = {
    serviceConfig = {
      EnvironmentFile = config.sops.templates."caddy.env".path;
    };
  };
}
