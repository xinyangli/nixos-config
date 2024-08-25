{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    types
    literalExpression
    mkIf
    mkDefault
    ;
  cfg = config.custom.miniflux;

  defaultAddress = "localhost:8080";

  pgbin = "${config.services.postgresql.package}/bin";
  preStart = pkgs.writeScript "miniflux-pre-start" ''
    #!${pkgs.runtimeShell}
    ${pgbin}/psql "miniflux" -c "CREATE EXTENSION IF NOT EXISTS hstore"
  '';
in
{
  options = {
    custom.miniflux = {
      enable = mkEnableOption "miniflux";

      package = mkPackageOption pkgs "miniflux" { };

      oauth2SecretFile = mkOption { type = types.path; };

      environment = mkOption {
        type =
          with types;
          attrsOf (oneOf [
            int
            str
          ]);
      };

      createDatabaseLocally = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether a PostgreSQL database should be automatically created and
          configured on the local host. If set to `false`, you need provision a
          database yourself and make sure to create the hstore extension in it.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.miniflux.enable = false;
    custom.miniflux.environment = {
      LISTEN_ADDR = mkDefault defaultAddress;
      RUN_MIGRATIONS = mkDefault 1;
      DATABASE_URL = lib.mkIf cfg.createDatabaseLocally "user=miniflux host=/run/postgresql dbname=miniflux";
      OAUTH2_CLIENT_SECRET_FILE = "%d/oauth2_secret";
      WATCHDOG = mkDefault 1;
    };

    services.postgresql = lib.mkIf cfg.createDatabaseLocally {
      enable = true;
      ensureUsers = [
        {
          name = "miniflux";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = [ "miniflux" ];
    };

    systemd.services.miniflux-dbsetup = lib.mkIf cfg.createDatabaseLocally {
      description = "Miniflux database setup";
      requires = [ "postgresql.service" ];
      after = [
        "network.target"
        "postgresql.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        User = config.services.postgresql.superUser;
        ExecStart = preStart;
      };
    };

    systemd.services.miniflux = {
      description = "Miniflux service";
      wantedBy = [ "multi-user.target" ];
      requires = lib.optional cfg.createDatabaseLocally "miniflux-dbsetup.service";
      after =
        [ "network.target" ]
        ++ lib.optionals cfg.createDatabaseLocally [
          "postgresql.service"
          "miniflux-dbsetup.service"
        ];

      serviceConfig = {
        Type = "notify";
        ExecStart = lib.getExe cfg.package;
        User = "miniflux";
        DynamicUser = true;
        LoadCredential = [ "oauth2_secret:${cfg.oauth2SecretFile}" ];
        RuntimeDirectory = "miniflux";
        RuntimeDirectoryMode = "0750";
        WatchdogSec = 60;
        WatchdogSignal = "SIGKILL";
        Restart = "always";
        RestartSec = 5;

        # Hardening
        CapabilityBoundingSet = [ "" ];
        DeviceAllow = [ "" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        UMask = "0077";
      };

      environment = lib.mapAttrs (_: toString) cfg.environment;
    };
    environment.systemPackages = [ cfg.package ];

    security.apparmor.policies."bin.miniflux".profile = ''
      include <tunables/global>
      ${cfg.package}/bin/miniflux {
        include <abstractions/base>
        include <abstractions/nameservice>
        include <abstractions/ssl_certs>
        include "${pkgs.apparmorRulesFromClosure { name = "miniflux"; } cfg.package}"
        r ${cfg.package}/bin/miniflux,
        r @{sys}/kernel/mm/transparent_hugepage/hpage_pmd_size,
        rw /run/miniflux/**,
      }
    '';
  };
}
