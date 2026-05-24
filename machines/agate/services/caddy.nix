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
      DESEC_TOKEN=${config.sops.placeholder."caddy-desec"}
    '';
  };

  networking.firewall.allowedTCPPorts = [ 8443 ];

  services.caddy.package = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/cloudflare@v0.2.1"
      "github.com/caddy-dns/desec@v1.1.0"
    ];
    hash = "sha256-xmdSGwBrB0G58Zfo03HwQmZh7kNpHBTmChwjK95SrMA=";
  };

  # Expose a gravity-VRF-scoped :443 socket so mesh-internal vhosts
  # (hydra.u.xiny.li etc.) can `bind` it via fdRefs.
  custom.mesh-network.caddy = {
    enable = true;
    ports = [ 443 ];
  };

  systemd.services.caddy = {
    serviceConfig = {
      EnvironmentFile = config.sops.templates."caddy.env".path;
    };
  };
}
