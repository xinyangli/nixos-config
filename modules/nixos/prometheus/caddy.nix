{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf (cfg.enable && cfg.exporters.caddy.enable) {
    services.caddy.globalConfig = lib.mkIf cfg.exporters.caddy.enable ''
      servers {
        metrics
      }
    '';

    services.prometheus.scrapeConfigs = [
      {
        job_name = "caddy";
        static_configs = [
          { targets = [ "127.0.0.1:2019" ]; }
        ];
      }
    ];

    custom.prometheus.ruleModules = [
      {
        name = "caddy_alerts";
        rules = [
          {
            alert = "UpstreamHealthy";
            expr = "caddy_reverse_proxy_upstreams_healthy != 1";
            for = "5m";
            labels = { severity = "critical"; };
            annotations = { summary = "Upstream {{ $labels.unstream }} not healthy"; };
          }
        ];
      }
    ];
  };

}
