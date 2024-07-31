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

  config = mkIf cfg.enable (mkMerge [
    {
      services.tailscale = {
        enable = true;
        permitCertUid = config.services.caddy.user;
      };

      services.caddy = {
        enable = true;
        virtualHosts."${config.networking.hostName}.coho-tet.ts.net".extraConfig = ''
          reverse_proxy 127.0.0.1:${toString config.services.prometheus.port}
        '';
      };

      services.caddy.globalConfig = ''
        servers {
          metrics
        }
      '';
      services.restic.server.prometheus = cfg.enable;
      services.gotosocial.settings = mkIf cfg.enable {
        metrics-enabled = true;
      };
      services.ntfy-sh.settings.enable-metrics = true;

      services.prometheus = mkIf cfg.enable
        {
          enable = true;
          port = 9091;
          globalConfig.external_labels = { hostname = config.networking.hostName; };
          remoteWrite = mkIf cfg.grafana.enable [
            {
              name = "grafana";
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
              enabledCollectors = [
                "conntrack"
                "diskstats"
                "entropy"
                "filefd"
                "filesystem"
                "loadavg"
                "meminfo"
                "netdev"
                "netstat"
                "stat"
                "time"
                "vmstat"
                "systemd"
                "logind"
                "interrupts"
                "ksmd"
              ];
              port = 9100;
            };
          };
          scrapeConfigs = [
            {
              job_name = "prometheus";
              static_configs = [
                { targets = [ "localhost:${toString config.services.prometheus.port}" ]; }
              ];
            }
            {
              job_name = "node";
              static_configs = [
                { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; }
              ];
            }
          ];

          alertmanager = {
            enable = true;
            listenAddress = "127.0.0.1";
            logLevel = "debug";
            configuration = {
              route = {
                receiver = "ntfy";
              };
              receivers = [
                {
                  name = "ntfy";
                  webhook_configs = [
                    {
                      url = "https://ntfy.xinyang.life/prometheus-alerts?tpl=yes&m=${lib.escapeURL ''
                        Alert {{.status}}
                        {{range .alerts}}-----{{range $k,$v := .labels}}
                        {{$k}}={{$v}}{{end}}
                        {{end}}
                      ''}";
                      send_resolved = true;
                    }
                  ];
                }
              ];
            };
          };

          alertmanagers = [
            {
              scheme = "http";
              static_configs = [
                {
                  targets = [
                    "${config.services.prometheus.alertmanager.listenAddress}:${toString config.services.prometheus.alertmanager.port}"
                  ];
                }
              ];
            }
          ];

          rules = let mkRule = condition: { ... }@rule: (if condition then [ rule ] else [ ]); in [
            (lib.generators.toYAML { } {
              groups = (mkRule true
                {
                  name = "system_alerts";
                  rules = [
                    {
                      alert = "SystemdFailedUnits";
                      expr = "node_systemd_unit_state{state=\"failed\"} > 0";
                      for = "5m";
                      labels = { severity = "critical"; };
                      annotations = { summary = "Systemd has failed units on {{ $labels.instance }}"; description = "There are {{ $value }} failed units on {{ $labels.instance }}. Immediate attention required!"; };
                    }
                    {
                      alert = "HighLoadAverage";
                      expr = "node_load1 > 0.8 * count without (cpu) (node_cpu_seconds_total{mode=\"idle\"})";
                      for = "1m";
                      labels = { severity = "warning"; };
                      annotations = { summary = "High load average detected on {{ $labels.instance }}"; description = "The 1-minute load average ({{ $value }}) exceeds 80% the number of CPUs."; };
                    }
                    {
                      alert = "HighTransmitTraffic";
                      expr = "rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m]) > 100000000";
                      for = "1m";
                      labels = { severity = "warning"; };
                      annotations = { summary = "High network transmit traffic on {{ $labels.instance }} ({{ $labels.device }})"; description = "The network interface {{ $labels.device }} on {{ $labels.instance }} is transmitting data at a rate exceeding 100 MB/s for the last 1 minute."; };
                    }
                  ];
                }) ++ (mkRule config.services.restic.server.enable {
                name = "restic_alerts";
                rules = [
                  {
                    alert = "ResticCheckFailed";
                    expr = "restic_check_success == 0";
                    for = "5m";
                    labels = { severity = "critical"; };
                    annotations = { summary = "Restic check failed (instance {{ $labels.instance }})"; description = "Restic check failed\\n  VALUE = {{ $value }}\\n  LABELS = {{ $labels }}"; };
                  }
                  {
                    alert = "ResticOutdatedBackup";
                    expr = "time() - restic_backup_timestamp > 518400";
                    for = "0m";
                    labels = { severity = "critical"; };
                    annotations = { summary = "Restic {{ $labels.client_hostname }} / {{ $labels.client_username }} backup is outdated"; description = "Restic backup is outdated\\n  VALUE = {{ $value }}\\n  LABELS = {{ $labels }}"; };
                  }
                ];
              }) ++ (mkRule config.services.caddy.enable {
                name = "caddy_alerts";
                rules = [
                  {
                    alert = "UpstreamHealthy";
                    expr = "caddy_reverse_proxy_upstreams_healthy == 0";
                    for = "5m";
                    labels = { severity = "critical"; };
                    annotations = { summary = "Upstream {{ $labels.unstream }} not healthy"; };
                  }
                  {
                    alert = "HighRequestLatency";
                    expr = "histogram_quantile(0.95, rate(caddy_http_request_duration_seconds_bucket[10m])) > 5";
                    for = "2m";
                    labels = { severity = "warning"; };
                    annotations = { summary = "High request latency on {{ $labels.instance }}"; description = "95th percentile of request latency is above 0.5 seconds for the last 2 minutes."; };
                  }
                ];
              });
            })
          ];
        };
    }
    {
      services.prometheus.scrapeConfigs = [
        (mkIf config.services.caddy.enable {
          job_name = "caddy";
          static_configs = [
            { targets = [ "localhost:2019" ]; }
          ];
        })
        (mkIf config.services.restic.server.enable {
          job_name = "restic";
          static_configs = [
            { targets = [ config.services.restic.server.listenAddress ]; }
          ];
        })
        (mkIf config.services.gotosocial.enable {
          job_name = "gotosocial";
          static_configs = [
            { targets = [ "localhost:${toString config.services.gotosocial.settings.port}" ]; }
          ];
        })
        (mkIf config.services.ntfy-sh.enable {
          job_name = "ntfy-sh";
          static_configs = [
            { targets = [ "auth.xinyang.life" ]; }
          ];
        })
      ];
    }
  ]);
}
