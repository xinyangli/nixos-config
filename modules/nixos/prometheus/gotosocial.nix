{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf (cfg.enable && cfg.exporters.gotosocial.enable) {
    services.gotosocial.settings = {
      metrics-enabled = true;
    };
    services.prometheus.scrapeConfigs = [
      {
        job_name = "gotosocial";
        static_configs = [
          { targets = [ "localhost:8080" ]; }
        ];
      }
    ];
  };
}
