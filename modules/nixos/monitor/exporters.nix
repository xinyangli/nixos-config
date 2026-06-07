{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf getExe;
  inherit (config.my-lib.settings) prometheusCollectors gravityInternalDomain;
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
      openFirewall = true;
      port = 9100;
    };

    services.caddy.virtualHosts."http://127.0.0.1:13131".extraConfig = ''
      header {
        # Required by Prometheus
        Content-Type "text/plain; version=0.0.4; charset=utf-8"
        Cache-Control "no-cache"
      }
      route /metrics {
        file_server {
          root /var/lib/caddy/comin-deployment-metrics
          hide /.*       # hide hidden files if needed
        }
      }
      route /* {
          respond "Not Found" 404
      }
    '';

    services.prometheus.exporters.blackbox = mkIf cfg.blackbox.enable {
      enable = true;
      listenAddress = cfg.blackbox.listenAddress;
      openFirewall = true;
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

    services.prometheus.exporters.v2ray = mkIf cfg.v2ray.enable {
      enable = true;
      listenAddress = cfg.v2ray.listenAddress;
      port = 9516;
      openFirewall = true;
      v2rayEndpoint = config.services.sing-box.settings.experimental.v2ray_api.listen;
    };

    # gotosocial
    sops.templates."gotosocial_metrics.env" = {
      content = ''
        GTS_METRICS_AUTH_ENABLED=true
        GTS_METRICS_AUTH_USERNAME=${config.sops.placeholder."prometheus/metrics_username"}
        GTS_METRICS_AUTH_PASSWORD=${config.sops.placeholder."prometheus/metrics_password"}
        OTEL_METRICS_PRODUCERS=prometheus
        OTEL_METRICS_EXPORTER=prometheus
        OTEL_EXPORTER_PROMETHEUS_PORT=9464
      '';
      group = "prometheus-auth";
      mode = "0440";
    };
    systemd.services.gotosocial.serviceConfig = {
      EnvironmentFile = [ config.sops.templates."gotosocial_metrics.env".path ];
      SupplementaryGroups = [ "prometheus-auth" ];
    };

    services.gotosocial.settings = {
      metrics-enabled = true;
    };

    services.immich.environment = {
      IMMICH_TELEMETRY_INCLUDE = "all";
    };

    services.restic.server.prometheus = true;

    # miniflux
    sops.templates."miniflux_metrics_env" = {
      content = ''
        METRICS_COLLECTOR=1
        LOG_LEVEL=debug
        METRICS_USERNAME=${config.sops.placeholder."prometheus/metrics_username"}
        METRICS_PASSWORD=${config.sops.placeholder."prometheus/metrics_password"}
      '';
      group = "prometheus-auth";
      mode = "0440";
    };

    systemd.services.miniflux.serviceConfig = {
      EnvironmentFile = [ config.sops.templates."miniflux_metrics_env".path ];
      SupplementaryGroups = [ "prometheus-auth" ];
    };

    services.ntfy-sh.settings.enable-metrics = true;
    services.caddy.globalConfig = ''
      metrics {
        per_host
      }
    '';
    networking.firewall.allowedTCPPorts = [ 2019 ];
  };
}
