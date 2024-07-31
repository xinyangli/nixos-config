{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf cfg.exporters.gotosocial.enable {
    services.gotosocial.settings = lib.mkIf cfg.exporters.gotosocial.enable {
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
