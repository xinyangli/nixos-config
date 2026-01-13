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
  commonSettings.backup = {
    enable = true;
    btrfsDevice = "/dev/sda2";
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
