
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
    };
  };

  config = {
    services.prometheus = mkIf cfg.enable {
      enable = true;
      port = 9091;
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
  };
}