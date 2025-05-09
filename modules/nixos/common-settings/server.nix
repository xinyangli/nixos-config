{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.commonSettings.serverComponents;
in
{
  options = {
    commonSettings.serverComponents = {
      enable = lib.mkEnableOption "Common components on servers";
    };
  };
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.1"
        ];
        hash = "sha256-saKJatiBZ4775IV2C5JLOmZ4BwHKFtRZan94aS5pO90=";
      };
    };

    services.caddy.globalConfig = ''
      servers {
        metrics
      }

      admin unix//var/run/caddy/admin.sock {
        origins 127.0.0.1 ${config.networking.hostName}.coho-tet.ts.net:2019
      }
    '';

    systemd.services.caddy.serviceConfig = {
      RuntimeDirectory = "caddy";
      RuntimeDirectoryMode = "0700";
    };

    custom.monitoring = {
      promtail.enable = true;
    };

    custom.prometheus.exporters = {
      enable = true;
      node.enable = true;
    };
  };
}
