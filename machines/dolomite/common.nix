{ config, lib, ... }:
{
  config = {
    sops = {
      secrets = {
        wg_private_key = {
          owner = "root";
          sopsFile = ./secrets + "/${config.networking.hostName}.yaml";
        };
        wg_ipv6_local_addr = {
          owner = "root";
          sopsFile = ./secrets + "/${config.networking.hostName}.yaml";
        };
        "sing-box/password" = {
          owner = "root";
          sopsFile = ./secrets/secrets.yaml;
        };
        "sing-box/uuid" = {
          owner = "root";
          sopsFile = ./secrets/secrets.yaml;
        };
      };
    };
    swapDevices = [
      {
        device = "/swapfile";
        size = 2 * 1024;
      }
    ];

    custom.prometheus.exporters = {
      enable = true;
      node.enable = true;
    };

    services.tailscale.enable = true;

    commonSettings = {
      auth.enable = true;
      proxyServer = {
        enable = true;
      };
    };
  };

}
