{ config, lib, ... }:
{
  config = {
    sops = {
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      defaultSopsFile = ./secrets/secrets.yaml;
      secrets = {
        wg_private_key = {
          owner = "root";
          sopsFile = ./secrets + "/${config.networking.hostName}.yaml";
        };
        wg_ipv6_local_addr = {
          owner = "root";
          sopsFile = ./secrets + "/${config.networking.hostName}.yaml";
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
      blackbox.enable = true;
      v2ray.enable = true;
    };

    custom.monitoring = {
      promtail.enable = true;
    };

    services.tailscale.enable = true;

    commonSettings = {
      auth.enable = true;
      proxyServer = {
        enable = true;
        users = [
          "wyj"
          "yhb"
          "xin"
        ];
      };
    };
  };

}
