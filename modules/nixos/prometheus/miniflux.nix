{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf (cfg.enable && cfg.exporters.miniflux.enable) {
    systemd.services.miniflux.environment.METRICS_COLLECTOR = "1";
    services.prometheus.scrapeConfigs = [
      {
        job_name = "miniflux";
        static_configs = [ { targets = [ config.systemd.services.miniflux.environment.LISTEN_ADDR ]; } ];
      }
    ];
  };
}
