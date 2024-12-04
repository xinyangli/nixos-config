{
  config,
  lib,
  pkgs,
  ...
}:
let
  sqliteBackup = fromPath: toPath: file: ''
    mkdir -p ${toPath}
    ${lib.getExe pkgs.sqlite} ${fromPath} ".backup '${toPath}/${file}'"
  '';
in
{
  sops.secrets = {
    "restic/repo_url" = { };
    "restic/repo_password" = { };
  };

  custom.restic = {
    enable = true;
    paths = [
      "/backup/db"
      "/backup/var/lib"
    ];
    backupPrepareCommand = [
      ''
        mkdir -p /backup/var
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /var/lib /backup/var/lib
      ''
    ];
    backupCleanupCommand = [
      ''
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /backup/var/lib
      ''
    ];
    btrfsRoots = [ ];
  };

  services.postgresqlBackup = lib.mkIf config.services.postgresql.enable {
    enable = true;
    compression = "zstd";
    compressionLevel = 9;
    location = "/backup/db/postgresql";
  };

  services.restic.backups.${config.networking.hostName} = {
    extraBackupArgs = [
      "--limit-upload=1024"
    ];
  };
}
