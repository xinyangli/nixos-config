{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    getExe
    ;

  cfg = config.custom.backup;
  hostName = config.networking.hostName;

  # Script to manage creation and deletion of snapshots
  # Runs within the restic service namespace (PrivateMounts=true)
  manageSnapshots = pkgs.writeShellScriptBin "manage-snapshots" ''
    set -euo pipefail
    action="$1"

    # Base directories
    # We use a directory in /run to mount the physical roots
    MOUNT_ROOT="/run/restic-btrfs-roots"

    # We sort mounts by length of mountpoint to handle nested mounts correctly (e.g. / then /home)
    # This ordering is baked into the script generation

    ${lib.concatMapStrings
      (
        snap:
        let
          # Unique identifier for this snapshot definition
          id = builtins.hashString "sha256" snap.mountpoint;
          deviceHash = builtins.hashString "sha256" snap.device;
          cleanSubvol = lib.removePrefix "/" (lib.removeSuffix "/" snap.subvol);
        in
        ''
          # Mountpoint for the btrfs device (root)
          dev_mountpoint="$MOUNT_ROOT/${deviceHash}"
          # Snapshot location inside the btrfs device
          snapshot_in_fs=".restic-snapshots/${id}"
          snapshot_path="$dev_mountpoint/$snapshot_in_fs"
          target_mountpoint="${snap.mountpoint}"

          if [[ "$action" == "setup" ]]; then
            # 1. Mount the btrfs root if not already mounted
            mkdir -p "$dev_mountpoint"
            if ! mountpoint -q "$dev_mountpoint"; then
              mount -t btrfs -o subvolid=5 "${snap.device}" "$dev_mountpoint"
            fi

            # 2. Create a snapshot
            mkdir -p "$(dirname "$snapshot_path")"
            
            # Cleanup old snapshot if exists (robustness)
            if [[ -d "$snapshot_path" ]]; then
               btrfs subvolume delete "$snapshot_path"
            fi
            
            echo "Creating snapshot for ${snap.subvol} on ${snap.device}"
            ${
              if cleanSubvol == "" || cleanSubvol == "." then
                ''
                  src_path="$dev_mountpoint"
                ''
              else
                ''
                  src_path="$dev_mountpoint/${cleanSubvol}"
                ''
            }
            
            btrfs subvolume snapshot -r "$src_path" "$snapshot_path"
            
            # 3. Bind mount the snapshot over the target location
            echo "Bind mounting snapshot to $target_mountpoint"
            # Ensure target exists? It should on a running system.
            mount --bind "$snapshot_path" "$target_mountpoint"

          elif [[ "$action" == "teardown" ]]; then
            echo "Cleaning up snapshot for $target_mountpoint"
            
            # 1. Unmount the bind mount
            # We try to unmount. If it fails (not mounted), we proceed.
            if mountpoint -q "$target_mountpoint"; then
               umount "$target_mountpoint" || echo "Warning: Failed to unmount $target_mountpoint"
            fi

            # 2. Ensure device is mounted to delete snapshot
            # (It might be unmounted if we are running in a fresh context, 
            # though backupCleanupCommand runs in same unit context usually)
            if ! mountpoint -q "$dev_mountpoint"; then
               mkdir -p "$dev_mountpoint"
               mount -t btrfs -o subvolid=5 "${snap.device}" "$dev_mountpoint" || true
            fi
            
            # 3. Delete snapshot
            if mountpoint -q "$dev_mountpoint" && [[ -d "$snapshot_path" ]]; then
               btrfs subvolume delete "$snapshot_path"
            fi
          fi
        ''
      )
      (
        lib.sort (a: b: (lib.stringLength a.mountpoint) < (lib.stringLength b.mountpoint)) (
          lib.attrValues cfg.btrfsSnapshot
        )
      )
    }

    # Global cleanup (teardown only)
    if [[ "$action" == "teardown" ]]; then
       # Unmount all device roots we mounted
       # We iterate over the directory if it exists
       if [[ -d "$MOUNT_ROOT" ]]; then
         for mnt in "$MOUNT_ROOT"/*; do
           if mountpoint -q "$mnt"; then
             umount "$mnt" || true
           fi
         done
         rm -rf "$MOUNT_ROOT"
       fi
    fi
  '';

in
{
  options.custom.backup = {
    enable = mkEnableOption "Atomic restic backup";

    paths = mkOption {
      type = types.listOf types.str;
      default = [
        "/home"
        "/var/lib"
      ];
      description = "Paths to backup";
    };

    btrfsSnapshot = mkOption {
      description = "Btrfs subvolumes to snapshot before backup. Key is the mountpoint.";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              device = mkOption {
                type = types.str;
                description = "Path to the device (e.g. /dev/sda1)";
              };
              subvol = mkOption {
                type = types.str;
                description = "Subvolume path relative to fs root";
              };
              mountpoint = mkOption {
                type = types.str;
                description = "Where this subvolume is mounted (defaults to attribute name)";
                default = name;
              };
            };
          }
        )
      );
    };

    prune = mkEnableOption "auto prune remote restic repo";
  };

  config = mkIf cfg.enable {
    # Configure the standard restic service
    sops.templates."restic_${hostName}_backup.env".content = ''
      AWS_ACCESS_KEY_ID=${config.sops.placeholder."restic/s3_access_key"}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."restic/s3_secret_key"}
    '';
    services.restic.backups.${hostName} = {
      repositoryFile = config.sops.secrets."restic/repo_url".path;
      passwordFile = config.sops.secrets."restic/repo_password".path;
      environmentFile = config.sops.templates."restic_${hostName}_backup.env".path;
      paths = cfg.paths;

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

      initialize = true;

      # Inject snapshot logic
      backupPrepareCommand = "${manageSnapshots}/bin/manage-snapshots setup";
      backupCleanupCommand = "${manageSnapshots}/bin/manage-snapshots teardown";
    };

    services.restic.server.prometheus = true;

    # We need to run in a private mount namespace to overlay snapshots safely
    systemd.services."restic-backups-${hostName}" = {
      path = [
        pkgs.util-linux
        pkgs.btrfs-progs
      ];

      serviceConfig = {
        PrivateMounts = true;
      };
    };
  };
}

