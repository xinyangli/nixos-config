{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf (cfg.enable && cfg.exporters.ntfy-sh.enable) {
    services.ntfy-sh.settings.enable-metrics = true;
    services.prometheus.scrapeConfigs = [
      {
        job_name = "ntfy-sh";
        static_configs = [ { targets = [ "ntfy.xinyang.life" ]; } ];
      }
    ];
  };
}
