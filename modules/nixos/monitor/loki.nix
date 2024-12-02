{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    ;
  cfg = config.custom.monitoring;
  port-loki = 3100;
in
{
  options = {
    custom.monitoring = {
      loki.enable = mkEnableOption "loki";
      promtail.enable = mkEnableOption "promtail";
    };
  };

  config = mkMerge [
    (mkIf cfg.loki.enable {
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          server.http_listen_address = "${config.networking.hostName}.coho-tet.ts.net";
          server.http_listen_port = port-loki;

          common = {
            ring = {
              instance_addr = "${config.networking.hostName}.coho-tet.ts.net";
              kvstore.store = "inmemory";
            };
            replication_factor = 1;
            path_prefix = "/var/lib/loki";
          };

          schema_config.configs = [
            {
              from = "2024-12-01";
              store = "boltdb-shipper";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];

          storage_config = {
            filesystem.directory = "/var/lib/loki/chunks";
          };

          limits_config = {
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
            allow_structured_metadata = false;
          };
        };
      };
    })
    (mkIf cfg.promtail.enable {
      services.promtail = {
        enable = true;
        configuration = {

          server = {
            http_listen_address = "${config.networking.hostName}.coho-tet.ts.net";
            http_listen_port = 28183;
            grpc_listen_port = 0;
          };

          positions.filename = "/tmp/positions.yml";

          clients = [
            {
              url = "http://thorite.coho-tet.ts.net:${toString port-loki}/loki/api/v1/push";
            }
          ];

          scrape_configs = [
            {
              job_name = "journal";
              # Copied from Mic92's config
              journal = {
                max_age = "12h";
                json = true;
                labels.job = "systemd-journal";
              };
              pipeline_stages = [
                {
                  json.expressions = {
                    transport = "_TRANSPORT";
                    unit = "_SYSTEMD_UNIT";
                    msg = "MESSAGE";
                    coredump_cgroup = "COREDUMP_CGROUP";
                    coredump_exe = "COREDUMP_EXE";
                    coredump_cmdline = "COREDUMP_CMDLINE";
                    coredump_uid = "COREDUMP_UID";
                    coredump_gid = "COREDUMP_GID";
                  };
                }
                {
                  # Set the unit (defaulting to the transport like audit and kernel)
                  template = {
                    source = "unit";
                    template = "{{if .unit}}{{.unit}}{{else}}{{.transport}}{{end}}";
                  };
                }
                {
                  regex = {
                    expression = "(?P<coredump_unit>[^/]+)$";
                    source = "coredump_cgroup";
                  };
                }
                {
                  template = {
                    source = "msg";
                    # FIXME would be cleaner to have this in a match block, but could not get it to work
                    template = "{{if .coredump_exe}}{{.coredump_exe}} core dumped (user: {{.coredump_uid}}/{{.coredump_gid}}, command: {{.coredump_cmdline}}){{else}}{{.msg}}{{end}}";
                  };
                }
                { labels.coredump_unit = "coredump_unit"; }
                {
                  # Normalize session IDs (session-1234.scope -> session.scope) to limit number of label values
                  replace = {
                    source = "unit";
                    expression = "^(session-\\d+.scope)$";
                    replace = "session.scope";
                  };
                }
                { labels.unit = "unit"; }
                {
                  # Write the proper message instead of JSON
                  output.source = "msg";
                }
                # silence nscd:
                # ignore random portscans on the internet
                { drop.expression = "refused connection: IN="; }
              ];
              relabel_configs = [
                {
                  source_labels = [ "__journal__hostname" ];
                  target_label = "host";
                }
              ];
            }
            # {
            #   job_name = "caddy-access";
            #   file_sd_configs = {
            #     files = [
            #       "/var/log/caddy/*.log"
            #     ];
            #     refresh_interval = "5m";
            #   };
            # }
          ];
        };
      };
    })
  ];
}
