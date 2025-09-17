{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.rustical;
  settingsFormat = pkgs.formats.toml { };
  configFile = settingsFormat.generate "config.toml" cfg.settings;
  defaultSettings = {
    data_store.sqlite = {
      db_url = "/var/lib/rustical/db.sqlite3";
    };

    http = {
      host = "127.0.0.1";
      port = 4000;
      session_cookie_samesite_strict = false;
    };

    frontend = {
      enabled = true;
      allow_password_login = true;
    };

    tracing = {
      opentelemetry = false;
    };

    dav_push = {
      enabled = true;
    };

    nextcloud_login = {
      enabled = true;
    };
  };
in
{
  options = {
    services.rustical = {
      enable = lib.mkEnableOption "Rustical calendar service";
      settings = lib.mkOption {
        type = settingsFormat.type;
        default = defaultSettings;
        example = {
          http.host = "127.0.0.1";
          http.port = "12512";
        };
        description = ''
          Contents of the Rustical TOML config.

          Please refer to the
          [documentation](https://lennart-k.github.io/rustical/_crate/rustical/config/index.html).
        '';
      };
      environmentFile = lib.mkOption {
        type = lib.type.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.rustical = {
      description = "ActivityPub social network server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [ configFile ];
      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "rustical";
        ExecStart = "${lib.getExe pkgs.rustical} -c ${configFile}";
      };
    };
  };
}
