{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    ;

  cfg = config.commonSettings.backup;
in
{
  options.commonSettings.backup = {
    enable = mkEnableOption "Common backup settings";
    btrfsDevice = mkOption {
      type = lib.types.nullOr lib.types.str;
    };
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "restic/repo_url" = { };
      "restic/repo_password" = { };
      "restic/s3_access_key" = {
        sopsFile = ../../../machines/secrets.yaml;
      };
      "restic/s3_secret_key" = {
        sopsFile = ../../../machines/secrets.yaml;
      };
    };

    custom.backup = {
      enable = true;
      paths = [
        "/home"
        "/var/lib"
        "/backup/db"
      ];
      btrfsSnapshot = mkIf (cfg.btrfsDevice != null) (
        lib.mkDefault {
          "/" = {
            device = cfg.btrfsDevice;
            subvol = "/rootfs";
          };
          "/home" = {
            device = cfg.btrfsDevice;
            subvol = "/home";
          };
          "/var/lib" = {
            device = cfg.btrfsDevice;
            subvol = "/persistent";
          };
        }
      );
    };
  };
}
