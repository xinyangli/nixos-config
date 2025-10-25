{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.matrix-authentication-service;
  format = pkgs.formats.yaml { };

  # remove null values from the final configuration
  finalSettings = lib.filterAttrsRecursive (_: v: v != null) cfg.settings;
  configFile = format.generate "config.yaml" finalSettings;
in
{
  options.services.matrix-authentication-service = {
    enable = lib.mkEnableOption (lib.mdDoc "matrix authentication service");

    package = lib.mkPackageOption pkgs "matrix-authentication-service" { };

    settings = lib.mkOption {
      default = { };
      description = lib.mdDoc ''
        The primary mas configuration. See the
        [configuration reference](https://matrix-org.github.io/matrix-authentication-service/usage/configuration.html)
        for possible values.

        Secrets should be passed in by using the `extraConfigFiles` option.
      '';
      type =
        with lib.types;
        submodule {
          freeformType = format.type;

          options = {
            http.public_base = lib.mkOption {
              type = lib.types.str;
            };
            http.issuer = lib.mkOption {
              type = lib.types.str;
            };
            http.trusted_proxies = lib.mkOption {
              type = lib.types.listOf (lib.types.str);
              default = [
                "192.168.0.0/16"
                "172.16.0.0/12"
                "10.0.0.0/10"
                "127.0.0.1/8"
                "fd00::/8"
                "::1/128"
              ];
            };
            http.listeners = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  freeformType = format.type;
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      example = "web";
                    };
                    proxy_protocol = lib.mkOption {
                      type = lib.types.bool;
                    };
                    resources = lib.mkOption {
                      type = lib.types.listOf (
                        lib.types.submodule {
                          freeformType = format.type;
                          options = {
                            name = lib.mkOption {
                              type = lib.types.str;
                            };
                            path = lib.mkOption {
                              type = lib.types.str;
                              default = "";
                            };
                          };
                        }
                      );
                    };
                    binds = lib.mkOption {
                      type = lib.types.listOf (
                        lib.types.submodule {
                          freeformType = format.type;
                          options = {
                            host = lib.mkOption {
                              type = lib.types.str;
                            };
                            port = lib.mkOption {
                              type = lib.types.ints.unsigned;
                            };
                          };
                        }
                      );
                    };
                  };
                }
              );
              default = [
                {
                  name = "web";
                  resources = [
                    { name = "discovery"; }
                    { name = "human"; }
                    { name = "oauth"; }
                    { name = "compat"; }
                    { name = "graphql"; }
                    {
                      name = "assets";
                      path = "${cfg.package}/share/matrix-authentication-service/assets";
                    }
                  ];
                  binds = [
                    {
                      host = "0.0.0.0";
                      port = 8080;
                    }
                  ];
                  proxy_protocol = false;
                }
                {
                  name = "internal";
                  resources = [
                    { name = "health"; }
                  ];
                  binds = [
                    {
                      host = "0.0.0.0";
                      port = 8081;
                    }
                  ];
                  proxy_protocol = false;
                }
              ];
            };

            database.uri = lib.mkOption {
              type = lib.types.str;
              default = "postgresql:///matrix-authentication-service?host=/run/postgresql";
              description = ''
                The postgres connection string.
                Refer to <https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING>.
              '';
            };

            database.max_connections = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 10;
            };

            database.min_connections = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 0;
            };

            database.connect_timeout = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 30;
            };

            database.idle_timeout = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 600;
            };

            database.max_lifetime = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 1800;
            };

            passwords.enabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };

            passwords.schemes = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  freeformType = format.type;
                  options = {
                    version = lib.mkOption {
                      type = lib.types.ints.unsigned;
                    };
                    algorithm = lib.mkOption {
                      type = lib.types.str;
                    };
                  };
                }
              );
              default = [
                {
                  version = 1;
                  algorithm = "argon2id";
                }
              ];
            };

            passwords.minimum_complexity = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 3;
            };

            matrix.homeserver = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = lib.mdDoc ''
                Corresponds to the server_name in the Synapse configuration file.
              '';
            };
            matrix.secret = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = lib.mdDoc ''
                A shared secret the service will use to call the homeserver admin API.
              '';
            };
            matrix.endpoint = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = lib.mdDoc ''
                The URL to which the homeserver is accessible from the service.
              '';
            };
          };
        };
    };

    createDatabase = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Whether to enable and configure `services.postgres` to ensure that the database user `matrix-authentication-service`
        and the database `matrix-authentication-service` exist.
      '';
    };

    extraConfigFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Extra config files to include.

        The configuration files will be included based on the command line
        argument --config. This allows to configure secrets without
        having to go through the Nix store, e.g. based on deployment keys if
        NixOps is in use.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = lib.optionalAttrs cfg.createDatabase {
      enable = true;
      ensureDatabases = [ "matrix-authentication-service" ];
      ensureUsers = [
        {
          name = "matrix-authentication-service";
          ensureDBOwnership = true;
        }
      ];
    };

    users.users.matrix-authentication-service = {
      group = "matrix-authentication-service";
      isSystemUser = true;
    };
    users.groups.matrix-authentication-service = { };

    systemd.services.matrix-authentication-service = rec {
      after =
        lib.optional cfg.createDatabase "postgresql.service"
        ++ lib.optional config.services.matrix-synapse.enable config.services.matrix-synapse.serviceUnit;
      wants = after;
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "matrix-authentication-service";
        Group = "matrix-authentication-service";
        ExecStartPre = [
          (
            "+"
            + (pkgs.writeShellScript "matrix-authentication-service-check-config" ''
              ${lib.getExe cfg.package} config check \
                ${lib.concatMapStringsSep " " (x: "--config ${x}") ([ configFile ] ++ cfg.extraConfigFiles)}
            '')
          )
        ];
        ExecStart = ''
          ${lib.getExe cfg.package} server \
            ${lib.concatMapStringsSep " " (x: "--config ${x}") ([ configFile ] ++ cfg.extraConfigFiles)} 
        '';
        Restart = "on-failure";
        RestartSec = "1s";
      };
    };
  };
}
