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
    internalDomain
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
        systemd.services.loki.serviceConfig.After = "tailscaled.service";
        services.loki = {
          enable = true;
          configuration = {
            auth_enabled = false;
            server.http_listen_address = "${config.networking.hostName}.${internalDomain}";
            server.http_listen_port = lokiPort;

            common = {
              ring = {
                instance_addr = "${config.networking.hostName}.${internalDomain}";
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
                local.directory = "${config.services.loki.dataDir}/rules";
              };
              rule_path = "${config.services.loki.dataDir}/rules-temp";
              enable_api = true;
              alertmanager_url = "http://127.0.0.1:${toString alertmanagerPort}";
            };
          };
        };
        systemd.tmpfiles.rules = [
          "d /var/lib/loki 0700 loki loki - -"
          "d /var/lib/loki/rules-temp 0700 loki loki - -"
          "d /var/lib/loki/rules 0700 loki loki - -"
          "d /var/lib/loki/rules/fake 0700 loki loki - -"
          "L /var/lib/loki/rules/fake/ruler.yml - - - - ${rulerFile}"
        ];
        systemd.services.loki.restartTriggers = [ rulerFile ];
      }
    )
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
                name = "modify";
                match = "*";
                add = "host ${config.networking.hostName}";
              }
            ];
            outputs = [
              {
                name = "loki";
                match = "*";
                host = "thorite.${internalDomain}";
                port = lokiPort;
                labels = "job=systemd-journal,host=${config.networking.hostName}";
                label_keys = "$_SYSTEMD_UNIT,$_HOSTNAME";
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
  ];
}
