{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.custom.prometheus;
  mkExporterOption = enableOption: (mkOption {
    type = types.bool;
    default = enableOption;
    description = "Enable this exporter";
  });

  mkRulesOption = mkOption {
    type = types.listOf (types.submodule {
      options = {
        name = mkOption {
          type = lib.types.str;
        };
        rules = mkOption {
          type = lib.types.listOf lib.types.attrs;
        };
      };
    });
  };
in
{
  imports = [
    ./blackbox.nix
    ./caddy.nix
    ./gotosocial.nix
    ./immich.nix
    ./ntfy-sh.nix
    ./restic.nix
  ];

  options = {
    custom.prometheus = {
      enable = mkEnableOption "Prometheus instance";
      exporters = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Prometheus exporter on every supported services";
        };

        restic.enable = mkExporterOption config.services.restic.server.enable;
        blackbox.enable = mkExporterOption false;
        caddy.enable = mkExporterOption config.services.caddy.enable;
        gotosocial.enable = mkExporterOption config.services.gotosocial.enable;
        immich.enable = mkExporterOption config.services.immich.enable;
        ntfy-sh.enable = mkExporterOption config.services.gotosocial.enable;
      };
      grafana = {
        enable = mkEnableOption "Grafana Cloud";
        password_file = mkOption {
          type = types.path;
        };
      };
      ruleModules = mkRulesOption;
    };
  };

  config = mkIf cfg.enable
    {
      services.tailscale = {
        enable = true;
        permitCertUid = config.services.caddy.user;
        openFirewall = true;
      };

      services.caddy = {
        enable = true;
        virtualHosts."${config.networking.hostName}.coho-tet.ts.net".extraConfig = ''
          reverse_proxy 127.0.0.1:${toString config.services.prometheus.port}
        '';
      };

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
                "diskstats"
                "loadavg"
                "time"
                "systemd"
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
          rules = [ (lib.generators.toYAML { } { groups = cfg.ruleModules; }) ];
        };
      custom.prometheus.ruleModules = [
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
            {
              alert = "NetworkTrafficExceedLimit";
              expr = ''increase(node_network_transmit_bytes_total{device!="lo",device!~"tailscale.*",device!~"wg.*",device!~"br.*"}[30d]) > 322122547200'';
              for = "0m";
              labels = { severity = "critical"; };
              annotations = { summary = "Outbound network traffic exceed 300GB for last 30 day"; };
            }
            {
              alert = "JobDown";
              expr = "up == 0";
              for = "1m";
              labels = { severity = "critical"; };
              annotations = { summary = "Job {{ $labels.job }} down for 1m."; };
            }
          ];
        }
      ];
    };
}
