{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.custom.immich;
  upstreamCfg = config.services.immich;
  settingsFormat = pkgs.formats.json { };
  user = config.systemd.services.immich-server.serviceConfig.User;
  group = config.systemd.services.immich-server.serviceConfig.Group;
in
{
  options = {
    custom.immich.jsonSettings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
      };
      default = { };
    };
  };
  config = {
    /*
      LoadCredential happens before preStart. We need to ensure the
      configuration file exist, otherwise LoadCredential will fail.
    */
    systemd.tmpfiles.settings = lib.mkIf upstreamCfg.enable {
      "10-etc-immich" = {
        "/etc/immich" = {
          d = {
            inherit user group;
            mode = "0700";
          };
        };
        "/etc/immich/config.json" = {
          "f+" = {
            inherit user group;
            mode = "0600";
          };
        };
      };
    };

    systemd.services.immich-server = {
      preStart = ''
        umask 0077
        ${utils.genJqSecretsReplacementSnippet cfg.jsonSettings "/etc/immich/config.json"}
      '';
      serviceConfig = {
        LoadCredential = "config:/etc/immich/config.json";
        Environment = "IMMICH_CONFIG_FILE=%d/config";
      };
    };

    # https://github.com/NixOS/nixpkgs/pull/324127/files#r1723763510
    services.immich.redis.host = "/run/redis-immich/redis.sock";
  };
}
