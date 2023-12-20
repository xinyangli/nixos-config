{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.custom.prometheus;
in
{
  options = {
    custom.prometheus = {
      enable = mkEnableOption "Prometheus instance";
      exporters = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Prometheus exporter on every supported services";
        };
      };
      grafana = {
        enable = mkEnableOption "Grafana Cloud";
        password_file = mkOption {
          type = types.path;
        };
      };
    };
  };

  config = mkMerge [{
    services.caddy.globalConfig = ''
      servers {
        metrics
      }
    '';
    services.restic.server.prometheus = cfg.enable;
    services.gotosocial.settings = {
      metrics-enable = true;
    };
    services.prometheus = mkIf cfg.enable {
      enable = true;
      port = 9091;
      globalConfig.external_labels = { hostname = config.networking.hostName; };
      remoteWrite = mkIf cfg.grafana.enable [
        { name = "grafana";
          url = "https://prometheus-prod-24-prod-eu-west-2.grafana.net/api/prom/push";
          basic_auth = {
            username = "1340065";
            password_file = cfg.grafana.password_file;
          };
        }
      ];
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9100;
        };
      };
      scrapeConfigs = [
        { job_name = "prometheus";
          static_configs = [
            { targets = [ "localhost:${toString config.services.prometheus.port}" ]; }
          ];
        }
        { job_name = "node";
          static_configs = [
            { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; }
          ];
        }
      ];
    };
  }
  {
    services.prometheus.scrapeConfigs = [
      ( mkIf config.services.caddy.enable {
        job_name = "caddy";
        static_configs = [
          { targets = [ "localhost:2019" ]; }
        ];
      })
      ( mkIf config.services.restic.server.enable {
        job_name = "restic";
        static_configs = [
          { targets = [ config.services.restic.server.listenAddress ]; }
        ];
      })
      ( mkIf config.services.gotosocial.enable {
        job_name = "gotosocial";
        static_configs = [
          { targets = [ "localhost:${toString config.services.gotosocial.settings.port}" ]; }
        ];
      })
    ];
  }
  ];
}
