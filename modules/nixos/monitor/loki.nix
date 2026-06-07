{
  pkgs,
  config,
  lib,
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
  inherit (config.my-lib.settings)
    alertmanagerPort
    gravityInternalDomain
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
                expr = mkOption {
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
      fluent-bit.enable = mkEnableOption "fluent-bit shipping the systemd journal to loki";
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
                inherit (opts) expr labels;
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
            server.http_listen_network = "unix";
            # loki appends :port to the socket path even for unix sockets
            # https://github.com/grafana/loki/issues/13898
            server.http_listen_address = "/run/loki/loki.sock";
            server.http_listen_port = lokiPort;

            common = {
              ring = {
                instance_addr = "127.0.0.1";
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
              retention_period = "30d";
            };

            compactor = {
              working_directory = "/var/lib/loki/compactor";
              compaction_interval = "10m";
              retention_enabled = true;
              retention_delete_delay = "2h";
              retention_delete_worker_count = 150;
              delete_request_store = "filesystem";
            };

            ruler = {
              storage = {
                type = "local";
                local.directory = "${config.services.loki.dataDir}/rules";
              };
              rule_path = "${config.services.loki.dataDir}/rules-temp";
              enable_api = true;
              alertmanager_url = "http://127.0.0.1:${toString alertmanagerPort}";
            };
          };
        };
        systemd.services.loki.serviceConfig.ExecStartPre =
          let
            script = pkgs.writeShellScript "loki-socket-remove-before-start" ''
              rm -rf /run/loki/loki.sock:${toString lokiPort}
              mkdir -p /run/loki
              chown loki:loki /run/loki
              exit 0
            '';
          in
          "+${script}";
        systemd.services.loki.serviceConfig.ExecStartPost =
          let
            script = pkgs.writeShellScript "loki-socket-perms" ''
              socket=/run/loki/loki.sock:${toString lokiPort}
              for i in $(seq 50); do
                [ -S "$socket" ] && chmod 0660 "$socket" && exit 0
                sleep 0.1
              done
              echo "loki socket not found after 5s" >&2
              exit 1
            '';
          in
          "+${script}";
        users.users.caddy.extraGroups = [ "loki" ];

        systemd.tmpfiles.rules = [
          "d /var/lib/loki 0700 loki loki - -"
          "d /var/lib/loki/rules-temp 0700 loki loki - -"
          "d /var/lib/loki/rules 0700 loki loki - -"
          "d /var/lib/loki/rules/fake 0700 loki loki - -"
          "d /var/lib/loki/compactor 0700 loki loki - -"
          "L /var/lib/loki/rules/fake/ruler.yml - - - - ${rulerFile}"
        ];
        systemd.services.loki.restartTriggers = [ rulerFile ];
      }
    )
    (mkIf cfg.loki.enable {
      services.caddy.virtualHosts."http://127.0.0.1:3100".extraConfig = ''
        reverse_proxy unix//run/loki/loki.sock:${toString lokiPort}
      '';
    })
    (mkIf (cfg.loki.enable && config.custom.mesh-network.caddy.enable) {
      custom.mesh-network.caddy.ports = [ 3100 ];
      services.caddy.virtualHosts."http://${config.networking.hostName}.loki.${gravityInternalDomain}:3100".extraConfig =
        ''
          bind ${config.custom.mesh-network.caddy.fdRefs."3100"}
          reverse_proxy unix//run/loki/loki.sock:${toString lokiPort}
        '';
    })
    (mkIf cfg.fluent-bit.enable {
      services.fluent-bit = {
        enable = true;
        settings = {
          service = {
            flush = 1;
            log_level = "info";
          };
          pipeline = {
            inputs = [
              {
                name = "systemd";
                tag = "host.*";
                read_from_tail = "on";
              }
            ];
            filters = [
              {
                name = "lua";
                match = "*";
                script = pkgs.writeText "fluent-bit-journal.lua" ''
                  local function basename(s)
                    return s:match("([^/]+)$") or s
                  end

                  function process(tag, ts, record)
                    local message = record["MESSAGE"] or ""

                    -- Drop high-volume noise we never want to ship
                    if string.find(message, "refused connection: IN=", 1, true) then
                      return -1, 0, 0
                    end

                    local unit = record["_SYSTEMD_UNIT"] or record["_TRANSPORT"] or ""
                    local host = record["_HOSTNAME"] or ""
                    local coredump_unit = nil

                    if record["COREDUMP_EXE"] then
                      message = string.format(
                        "%s core dumped (user: %s/%s, command: %s)",
                        record["COREDUMP_EXE"],
                        record["COREDUMP_UID"] or "",
                        record["COREDUMP_GID"] or "",
                        record["COREDUMP_CMDLINE"] or ""
                      )
                      if record["COREDUMP_CGROUP"] then
                        coredump_unit = basename(record["COREDUMP_CGROUP"])
                      end
                    end

                    -- Collapse session-1234.scope -> session.scope so we don't
                    -- explode the cardinality of the unit label.
                    unit = unit:gsub("^session%-%d+%.scope$", "session.scope")

                    local new_record = {
                      message = message,
                      host = host,
                      unit = unit,
                    }
                    if coredump_unit then
                      new_record.coredump_unit = coredump_unit
                    end
                    return 1, ts, new_record
                  end
                '';
                call = "process";
              }
            ];
            outputs = [
              {
                name = "loki";
                match = "*";
                host = "thorite.loki.${gravityInternalDomain}";
                port = lokiPort;
                labels = "job=systemd-journal";
                label_keys = "$host,$unit,$coredump_unit";
                remove_keys = "host,unit,coredump_unit";
                line_format = "json";
              }
            ];
          };
        };
      };

      services.caddy.logFormat = lib.mkIf config.services.caddy.enable ''
        format json
        level INFO
      '';
    })
    (mkIf (cfg.fluent-bit.enable && config.custom.mesh-network.ipsec.enable) {
      systemd.services.fluent-bit.serviceConfig.BindNetworkInterface = "gravity";
    })
  ];
}
