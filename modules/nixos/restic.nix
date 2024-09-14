# TODO: https://github.com/lilyinstarlight/foosteros/blob/dfe1ab3eb68bfebfaa709482d52fa04ebdde81c8/config/restic.nix#L23 <- this is better
{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.restic;
in
{
  options = {
    custom.restic = {
      enable = lib.mkEnableOption "restic";
      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "/home"
          "/var/lib"
        ];
      };
      prune = lib.mkEnableOption "auto prune remote restic repo";
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
  config = lib.mkIf cfg.enable {
    services.restic.backups.${config.networking.hostName} = lib.mkMerge [
      {
        repositoryFile = cfg.repositoryFile;
        passwordFile = cfg.passwordFile;
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
        pruneOpts = lib.mkIf cfg.prune [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
        paths = lib.mkDefault cfg.paths;
        initialize = true;
      }
      (lib.mkIf (config.fileSystems."/".fsType == "btrfs") {
        backupPrepareCommand = ''
          btrfs subvolume snapshot -r / backup
        '';
        backupCleanupCommand = ''
          btrfs subvolume delete /backup 
        '';
        paths = map (p: "/backup" + p) cfg.paths;
      })
    ];
  };
}
