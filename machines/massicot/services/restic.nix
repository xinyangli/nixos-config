{
  config,
  lib,
  pkgs,
  ...
}:
let
  sqliteBackup = path: ''
    mkdir -p /backup${path}
    ${lib.getExe pkgs.sqlite} ${path} "vacuum into '/var/backup${path}'"
  '';
in
{
  sops.secrets = {
    "restic/repo" = {
      sopsFile = ../secrets.yaml;
    };
    "restic/password" = {
      sopsFile = ../secrets.yaml;
    };
  };

  custom.restic = {
    enable = true;
    repositoryFile = config.sops.secrets."restic/repo".path;
    passwordFile = config.sops.secrets."restic/password".path;
    paths = [
      "/var/backup"
      "/mnt/storage"
    ];
  };

  services.postgresqlBackup = {
    enable = true;
    compression = "zstd";
    compressionLevel = 9;
    location = "/var/backup/postgresql";
  };

  services.restic.backups.${config.networking.hostName} = {
    backupPrepareCommand = builtins.concatStringsSep "\n" [
      (sqliteBackup "/var/lib/hedgedoc/db.sqlite")
      (sqliteBackup "/var/lib/bitwarden_rs/db.sqlite3")
      (sqliteBackup "/var/lib/gotosocial/database.sqlite")
      (sqliteBackup "/var/lib/kanidm/kanidm.db")
    ];
    extraBackupArgs = [
      "--limit-upload=1024"
    ];
  };
}
