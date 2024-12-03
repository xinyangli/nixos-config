{
  pkgs,
  config,
  lib,
  my-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    mkMerge
    types
    literalExpression
    ;
  inherit (my-lib.settings)
    alertmanagerPort
    ;
  cfg = config.custom.monitoring;
  lokiPort = 3100;
in
{
  options = {
    custom.monitoring = {
      loki = {
        enable = mkEnableOption "loki";
        rules = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                condition = mkOption {
                  type = types.str;
                  description = ''
                    Loki alert expression.
                  '';
                  example = ''count_over_time({job=~"secure"} |="sshd[" |~": Failed|: Invalid|: Connection closed by authenticating user" | __error__="" [15m]) > 15'';
                  default = null;
                };
                description = mkOption {
                  type = types.str;
                  description = ''
                    Loki alert message.
                  '';
                  example = "Prometheus encountered value {{ $value }} with {{ $labels }}";
                  default = null;
                };
                labels = mkOption {
                  type = types.nullOr (types.attrsOf types.str);
                  description = ''
                    Additional alert labels.
                  '';
                  example = literalExpression ''
                    { severity = "page" };
                  '';
                  default = { };
                };
                time = mkOption {
                  type = types.str;
                  description = ''
                    Time until the alert is fired.
                  '';
                  example = "5m";
                  default = "2m";
                };
              };
            }
          );
          description = ''
            Defines the loki rules.
          '';
          default = { };
        };
      };
      promtail.enable = mkEnableOption "promtail";
    };
  };

  config = mkMerge [
    (
      let
        rulerConfig = {
          groups = [
            {
              name = "alerting-rules";
              rules = lib.mapAttrsToList (name: opts: {
                alert = name;
                inherit (opts) condition labels;
                for = opts.time;
                annotations.description = opts.description;
              }) cfg.loki.rules;
            }
          ];
        };
        rulerFile = pkgs.writeText "ruler.yml" (builtins.toJSON rulerConfig);
      in
      mkIf cfg.loki.enable {
        services.loki = {
          enable = true;
          configuration = {
            auth_enabled = false;
            server.http_listen_address = "${config.networking.hostName}.coho-tet.ts.net";
            server.http_listen_port = lokiPort;

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

            ruler = {
              storage = {
                type = "local";
                local.directory = "${config.services.loki.dataDir}/ruler";
              };
              rule_path = "${config.services.loki.dataDir}/rules";
              alertmanager_url = "http://127.0.0.1:${toString alertmanagerPort}";
            };
          };
        };
        systemd.tmpfiles.rules = [
          "d /var/lib/loki 0700 loki loki - -"
          "d /var/lib/loki/ruler 0700 loki loki - -"
          "d /var/lib/loki/rules 0700 loki loki - -"
          "L /var/lib/loki/ruler/ruler.yml - - - - ${rulerFile}"
        ];
        systemd.services.loki.reloadTriggers = [ rulerFile ];
      }
    )
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
              url = "http://thorite.coho-tet.ts.net:${toString lokiPort}/loki/api/v1/push";
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
