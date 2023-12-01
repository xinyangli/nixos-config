{ config, pkgs, lib, ... }:
let
  cfg = config.custom.restic;
in
{
  options = {
    custom.restic = {
      enable = lib.mkEnableOption "restic";
      repositoryFile = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      passwordFile = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };
  config = {
    services.restic.backups = lib.mkIf cfg.enable {
      remotebackup = {
        repositoryFile = cfg.repositoryFile;
        passwordFile = cfg.passwordFile;
        paths = [
          "/home"
          "/var/lib"
        ];
        exclude = [
          "/home/*/.cache"
          "/home/*/.cargo"
          "/home/*/.local/share/Steam"
          "/home/*/.local/share/flatpak"
        ];
        timerConfig = {
          OnCalendar = "00:05";
          RandomizedDelaySec = "5h";
        };
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
      };
    };
  };
}

