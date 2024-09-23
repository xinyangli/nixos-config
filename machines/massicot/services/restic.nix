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
      "/backup"
      "/mnt/storage"
    ];
  };

  services.postgresqlBackup = {
    enable = true;
    compression = "zstd";
    compressionLevel = 9;
    location = "/backup/postgresql";
  };

  services.restic.backups.${config.networking.hostName} = {
    backupPrepareCommand = builtins.concatStringsSep "\n" [
      (sqliteBackup "/var/lib/hedgedoc/db.sqlite" "/backup/hedgedoc" "db.sqlite")
      (sqliteBackup "/var/lib/bitwarden_rs/db.sqlite3" "/backup/bitwarden_rs" "db.sqlite3")
      (sqliteBackup "/var/lib/gotosocial/database.sqlite" "/backup/gotosocial" "database.sqlite")
      (sqliteBackup "/var/lib/kanidm/kanidm.db" "/backup/kanidm" "kanidm.db")
    ];
    extraBackupArgs = [
      "--limit-upload=1024"
    ];
  };
}
