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
    "restic/repo_url" = {
      sopsFile = ../secrets.yaml;
    };
    "restic/repo_password" = {
      sopsFile = ../secrets.yaml;
    };
  };

  custom.restic = {
    enable = true;
    paths = [
      "/backup"
      "/mnt/storage"
    ];
    backupPrepareCommand = [
      (sqliteBackup "/var/lib/hedgedoc/db.sqlite" "/backup/hedgedoc" "db.sqlite")
      (sqliteBackup "/var/lib/bitwarden_rs/db.sqlite3" "/backup/bitwarden_rs" "db.sqlite3")
      (sqliteBackup "/var/lib/gotosocial/database.sqlite" "/backup/gotosocial" "database.sqlite")
      (sqliteBackup "/var/lib/kanidm/kanidm.db" "/backup/kanidm" "kanidm.db")
    ];
  };

  services.restic.backups.${config.networking.hostName} = {
    extraBackupArgs = [
      "--limit-upload=1024"
    ];
  };
}
