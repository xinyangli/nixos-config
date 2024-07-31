{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf cfg.enable {
    services.ntfy-sh.settings.enable-metrics = true;
    services.prometheus.scrapeConfigs = [
      (lib.mkIf cfg.exporters.ntfy-sh.enable {
        job_name = "ntfy-sh";
        static_configs = [
          { targets = [ "ntfy.xinyang.life" ]; }
        ];
      })
    ];
  };
}
