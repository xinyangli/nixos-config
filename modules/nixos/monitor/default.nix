{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkMerge
    types
    ;
  inherit (config.my-lib.settings) ntfyUrl;
  cfg = config.custom.prometheus;

  mkRulesOption = mkOption {
    type = types.listOf (
      types.submodule {
        options = {
          name = mkOption { type = lib.types.str; };
          rules = mkOption { type = lib.types.listOf lib.types.attrs; };
        };
      }
    );
  };
in
{
  imports = [
    ./exporters.nix
    ./grafana.nix
    ./loki.nix
  ];

  options = {
    custom.monitoring = {
      grafana = {
        enable = mkEnableOption "grafana with oauth only";
      };
    };
    custom.prometheus = {
      enable = mkEnableOption "Prometheus instance";
      ruleModules = mkRulesOption;
      exporters = {
        enable = mkEnableOption "prometheus exporter on all supported and enable guarded services";
        node = {
          enable = mkEnableOption "node exporter";
          listenAddress = mkOption {
            type = types.str;
            default = "${config.networking.hostName}.coho-tet.ts.net";
          };
        };
        blackbox = {
          enable = mkEnableOption "blackbox exporter";
          listenAddress = mkOption {
            type = types.str;
            default = "${config.networking.hostName}.coho-tet.ts.net";
          };
        };
        v2ray = {
          enable = mkEnableOption "blackbox exporter";
          listenAddress = mkOption {
            type = types.str;
            default = "${config.networking.hostName}.coho-tet.ts.net";
          };
        };
      };
    };
  };

  config = mkMerge [
    {
      sops.secrets = {
        "prometheus/metrics_username" = {
          sopsFile = ../../../machines/secrets.yaml;
          group = "prometheus-auth";
          mode = "0440";
        };

        "prometheus/metrics_password" = {
          sopsFile = ../../../machines/secrets.yaml;
          group = "prometheus-auth";
          mode = "0440";
        };
      };

      users.groups.prometheus-auth.members = [
        "prometheus"
      ];
    }
    (mkIf cfg.enable {
      services.caddy.virtualHosts."${config.networking.hostName}.coho-tet.ts.net".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.services.prometheus.port}
      '';
      services.prometheus = mkIf cfg.enable {
        enable = true;
        port = 9091;
        globalConfig.external_labels = {
          hostname = config.networking.hostName;
        };

        scrapeConfigs = [
          {
            job_name = "prometheus";
            static_configs = [ { targets = [ "localhost:${toString config.services.prometheus.port}" ]; } ];
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
                    url = "${ntfyUrl}/prometheus-alerts?tpl=yes&m=%7B%7Brange%20.alerts%7D%7D%7B%7Bif%20eq%20.status%20%22resolved%22%7D%7D%E2%9C%85%7B%7Belse%7D%7D%F0%9F%94%A5%7B%7Bend%7D%7D%20%7B%7B.annotations.summary%7D%7D%0A%7B%7Bend%7D%7D";
                    send_resolved = true;
                    max_alerts = 10;
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
          name = "prometheus_alerts";
          rules = [
            {
              alert = "JobDown";
              expr = "up == 0";
              for = "1m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "Job {{ $labels.job }} on instance {{ $labels.instance | reReplaceAll \"^(.{10}).*\" \"$1\" }} is down.";
              };
            }
          ];
        }
      ];
    })
  ];
}
