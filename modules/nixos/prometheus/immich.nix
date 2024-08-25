{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
  immichEnv = config.services.immich.environment;
  metricPort =
    if builtins.hasAttr "IMMICH_API_METRICS_PORT" immichEnv then
      immichEnv.IMMICH_API_METRICS_PORT
    else
      8081;
in
{
  config = lib.mkIf (cfg.enable && cfg.exporters.immich.enable) {
    services.immich.environment = {
      IMMICH_METRICS = "true";
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "immich";
        static_configs = [ { targets = [ "127.0.0.1:${toString metricPort}" ]; } ];
      }
    ];
  };

}
