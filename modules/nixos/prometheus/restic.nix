{ config, lib, ... }:
let
  cfg = config.custom.prometheus;
in
{
  config = lib.mkIf cfg.enable {
    services.restic.server.prometheus = true;

    services.prometheus.scrapeConfigs = [
      (lib.mkIf cfg.exporters.restic.enable {
        job_name = "restic";
        static_configs = [
          { targets = [ config.services.restic.server.listenAddress ]; }
        ];
      })
    ];

    custom.prometheus.ruleModules = [
      (lib.mkIf cfg.exporters.restic.enable {
        name = "restic_alerts";
        rules = [
          {
            alert = "ResticCheckFailed";
            expr = "restic_check_success == 0";
            for = "5m";
            labels = { severity = "critical"; };
            annotations = { summary = "Restic check failed (instance {{ $labels.instance }})"; description = "Restic check failed\\n  VALUE = {{ $value }}\\n  LABELS = {{ $labels }}"; };
          }
          {
            alert = "ResticOutdatedBackup";
            expr = "time() - restic_backup_timestamp > 518400";
            for = "0m";
            labels = { severity = "critical"; };
            annotations = { summary = "Restic {{ $labels.client_hostname }} / {{ $labels.client_username }} backup is outdated"; description = "Restic backup is outdated\\n  VALUE = {{ $value }}\\n  LABELS = {{ $labels }}"; };
          }
        ];
      })
    ];
  };

}
