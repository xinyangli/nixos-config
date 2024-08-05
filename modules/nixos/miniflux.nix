{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.custom.miniflux;
in
{
  options = {
    custom.miniflux = {
      enable = mkEnableOption "miniflux";
      oauth2SecretFile = mkOption {
        type = types.path;
      };
      environmentFile = mkOption {
        type = types.path;
        default = "/dev/null";
      };
      environment = mkOption {
        type = with types; attrsOf (oneOf [ int str ]);
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.miniflux = {
      enable = true;
      adminCredentialsFile = cfg.environmentFile;
    };
    systemd.services.miniflux = {
      serviceConfig = {
        LoadCredential = [ "oauth2_secret:${cfg.oauth2SecretFile}" ];
        EnvironmentFile = [ "%d/oauth2_secret" ];
      };
      environment = lib.mapAttrs (_: lib.mkForce) (lib.mapAttrs (_: toString) cfg.environment);
    };
  };
}
