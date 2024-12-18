{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf concatStringsSep;
  inherit (config.my-lib.settings) prometheusCollectors;
  cfg = config.custom.prometheus.exporters;
in
{
  config = {
    systemd.services.tailscaled.after =
      (lib.optional cfg.node.enable "prometheus-node-exporters.service")
      ++ (lib.optional cfg.blackbox.enable "prometheus-blackbox-exporters.service")
      ++ (lib.optional config.services.caddy.enable "caddy.service");

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

    services.prometheus.exporters.v2ray = mkIf cfg.v2ray.enable {
      enable = true;
      listenAddress = cfg.v2ray.listenAddress;
      port = 9516;
      v2rayEndpoint = config.services.sing-box.settings.experimental.v2ray_api.listen;
    };

    # gotosocial
    sops.templates."gotosocial_metrics.env" = {
      content = ''
        GTS_METRICS_AUTH_ENABLED=true
        GTS_METRICS_AUTH_USERNAME=${config.sops.placeholder."prometheus/metrics_username"}
        GTS_METRICS_AUTH_PASSWORD=${config.sops.placeholder."prometheus/metrics_password"}
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

    services.tailscale = {
      permitCertUid = config.services.caddy.user;
      openFirewall = true;
    };

    services.caddy = {
      virtualHosts."https://${config.networking.hostName}.coho-tet.ts.net:2019".extraConfig = ''
        handle /metrics {
        	reverse_proxy unix//var/run/caddy/admin.sock
        }
        respond 403
      '';
    };
  };
}
