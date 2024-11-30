{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.custom.prometheus.exporters;
in
{
  config = {
    services.prometheus.exporters.node = mkIf cfg.node.enable {
      enable = true;
      enabledCollectors = [
        "loadavg"
        "time"
        "systemd"
      ];
      listenAddress = cfg.node.listenAddress;
      port = 9100;
    };

    services.prometheus.exporters.blackbox = mkIf cfg.blackbox.enable {
      enable = true;
      listenAddress = cfg.blackbox.listenAddress;
      configFile = pkgs.writeText "blackbox.config.yaml" (
        lib.generators.toYAML { } {
          modules = {
            tcp4_connect = {
              prober = "tcp";
              tcp = {
                ip_protocol_fallback = false;
                preferred_ip_protocol = "ip4";
                tls = false;
              };
              timeout = "15s";
            };
          };
        }
      );
    };

    services.gotosocial.settings = {
      metrics-enabled = true;
    };

    services.immich.environment = {
      IMMICH_TELEMETRY_INCLUDE = "all";
    };

    services.restic.server.prometheus = true;
    systemd.services.miniflux.environment.METRICS_COLLECTOR = "1";
    services.ntfy-sh.settings.enable-metrics = true;

    services.caddy.globalConfig = ''
      servers {
        metrics
      }

      admin ${config.networking.hostName}.coho-tet.ts.net:2019 {
      }
    '';
  };
}
