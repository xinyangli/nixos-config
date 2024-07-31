{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf cfg.enable {
    services.caddy.globalConfig = lib.mkIf cfg.exporters.caddy.enable ''
      servers {
        metrics
      }
    '';

    services.prometheus.scrapeConfigs = [
      (lib.mkIf cfg.exporters.caddy.enable {
        job_name = "caddy";
        static_configs = [
          { targets = [ "127.0.0.1:2019" ]; }
        ];
      })
    ];

    custom.prometheus.ruleModules = [
      (lib.mkIf cfg.exporters.caddy.enable {
        name = "caddy_alerts";
        rules = [
          {
            alert = "UpstreamHealthy";
            expr = "caddy_reverse_proxy_upstreams_healthy != 1";
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
      })
    ];
  };

}
