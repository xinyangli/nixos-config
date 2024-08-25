{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf (cfg.enable && cfg.exporters.blackbox.enable) {
    services.prometheus.exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
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

    services.prometheus.scrapeConfigs = [
      {
        job_name = "blackbox";
        scrape_interval = "1m";
        metrics_path = "/probe";
        params = {
          module = [ "tcp4_connect" ];
        };
        static_configs = [
          {
            targets = [
              "tok-00.namely.icu:8080"
              "la-00.video.namely.icu:8080"
              "auth.xinyang.life:443"
              "home.xinyang.life:8000"
            ];
          }
        ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
          }
        ];
      }
      {
        job_name = "blackbox_exporter";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}" ]; }
        ];
      }
    ];

    custom.prometheus.ruleModules = [
      {
        name = "probe_alerts";
        rules = [
          {
            alert = "HighProbeLatency";
            expr = "probe_duration_seconds > 0.5";
            for = "2m";
            labels = {
              severity = "warning";
            };
            annotations = {
              summary = "High request latency on {{ $labels.instance }}";
              description = "95th percentile of request latency is above 0.5 seconds for the last 2 minutes.";
            };
          }
        ];
      }
    ];
  };
}
