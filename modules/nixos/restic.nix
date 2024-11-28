# TODO: https://github.com/lilyinstarlight/foosteros/blob/dfe1ab3eb68bfebfaa709482d52fa04ebdde81c8/config/restic.nix#L23 <- this is better
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkDefault
    mkIf
    types
    getExe
    ;
  cfg = config.custom.restic;
  mapBtrfsRoots =
    rootDir:
    let
      backupDir = lib.removeSuffix "/" "/backup${rootDir}";
      slash = if rootDir == "/" then "" else "/";
      awk = getExe pkgs.gawk;
      continueIfInExclude = ''
        exclude_subv="${toString cfg.btrfsExcludeSubvolume}"
        found=false
        for subv in $exclude_subv; do
            if [[ "$subvol" == "$subv" ]]; then
                found=true
                echo "$subvol is in exclude subvolumes, skipped"
                break
            fi
        done
        $found && continue
      '';
    in
    {
      backupPrepareCommand = ''
        echo "Creating snapshot for ${rootDir}"
        subvolumes=$(${pkgs.btrfs-progs}/bin/btrfs subvolume list -o "${rootDir}" | ${awk} '{print $NF}')
        mkdir -p "${backupDir}"
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r "${rootDir}" "${backupDir}/rootfs"
        for subvol in $subvolumes; do
            ${continueIfInExclude}
            [[ /"$subvol" == "${backupDir}"* ]] && continue

            snapshot_path=$(dirname "${backupDir}/$subvol")
            mkdir -p "$snapshot_path"

            echo "Creating snapshot for subvolume: $subvol at $snapshot_path"
            ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r "${rootDir}${slash}$subvol" "$snapshot_path"
        done
      '';

      # Note that all the manually created snapshots under backupDir will also be cleaned
      backupCleanupCommand = ''
        # Only find snapshots under backup directory
        subvolumes=$(${pkgs.btrfs-progs}/bin/btrfs subvolume list -s -o "${backupDir}" | ${awk} '{print $NF}')
        for subvol in $subvolumes; do
            echo "Removing snapshot for subvolume: $subvol"
            ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$subvol"
        done
      '';
    };

  btrfsFs = lib.attrsets.filterAttrs (
    n: v: v.fsType == "btrfs" && ((isNull cfg.btrfsRoots) || (builtins.elem n cfg.btrfsRoots))
  ) config.fileSystems;
  btrfsFsRoot = builtins.attrNames btrfsFs;
  btrfsCommands = (map mapBtrfsRoots btrfsFsRoot);
in
{
  options = {
    custom.restic = {
      enable = mkEnableOption "restic";
      paths = mkOption {
        type = types.listOf types.str;
        default = [
          "/home"
          "/var/lib"
        ];
      };
      prune = mkEnableOption "auto prune remote restic repo";
      btrfsRoots = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = [ "/" ];
        description = ''
          Includeded btrfs roots. `null` means snapshot all btrfs filesystems under config.fileSystems.
        '';
      };
      btrfsExcludeSubvolume = mkOption {
        type = types.listOf types.str;
        default = [
          "nix"
          "rootfs"
          "swap"
          "var/tmp"
        ];
        example = lib.literalExpression ''
          [ "var/tmp" "srv" ]
        '';
      };
      backupPrepareCommand = mkOption {
        type = types.listOf types.str;
      };
      backupCleanupCommand = mkOption {
        type = types.listOf types.str;
      };
    };
  };
  config = mkIf cfg.enable {
    services.restic.backups.${config.networking.hostName} = {
      repositoryFile = config.sops.secrets."restic/repo_url".path;
      passwordFile = config.sops.secrets."restic/repo_password".path;
      exclude = [
        "**/.cache"
        "**/.local/share/Steam"
        "**/.local/share/flatpak"

        "**/.cargo"
        "**/.rustup"

        "**/node_modules"

        "*.pyc"
        "*.pyo"
        "**/__pycache__"
        "**/.virtualenvs"
        "**/.venv"

        # temp files / lock files
        "*.sqlite-wal"
        "*.sqlite-shm"
        "*.db-wal"
        "*.db-shm"
      ];
      timerConfig = {
        OnCalendar = "00:05";
        RandomizedDelaySec = "5h";
      };
      pruneOpts = mkIf cfg.prune [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
      ];
      paths = mkDefault cfg.paths;
      initialize = true;
      backupPrepareCommand = lib.strings.concatLines cfg.backupPrepareCommand;
      backupCleanupCommand = lib.strings.concatLines cfg.backupCleanupCommand;
    };
    custom.restic.backupPrepareCommand = map (x: x.backupPrepareCommand) btrfsCommands;
    custom.restic.backupCleanupCommand = map (x: x.backupCleanupCommand) btrfsCommands;
  };
}
