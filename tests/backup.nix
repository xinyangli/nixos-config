{ pkgs, ... }:

{
  name = "backup-btrfs-snapshot-test";

  nodes.machine =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        ../modules/nixos/backup.nix
      ];

      # Mock sops-nix secrets which backup.nix expects
      options.sops = {
        secrets = lib.mkOption {
          type = lib.types.attrs;
          default = { };
        };
        templates = lib.mkOption {
          type = lib.types.attrs;
          default = { };
        };
        placeholder = lib.mkOption {
          type = lib.types.attrs;
          default = { };
        };
      };

      config =
        let
          disk = config.virtualisation.rootDevice;
        in
        {
          virtualisation.rootDevice = "/dev/vda";
          virtualisation.useDefaultFilesystems = false;
          virtualisation.fileSystems = {
            "/" = {
              device = disk;
              fsType = "btrfs";
              options = [ "subvol=/root" ];
            };

            "/home" = {
              device = disk;
              fsType = "btrfs";
              options = [ "subvol=/home" ];
            };

            "/var/lib" = {
              device = disk;
              fsType = "btrfs";
              options = [ "subvol=/persistent" ];
            };
          };
          boot.initrd.availableKernelModules = [ "btrfs" ];
          boot.supportedFilesystems = [ "btrfs" ];
          boot.initrd.postDeviceCommands = ''
            FSTYPE=$(blkid -o value -s TYPE ${disk} || true)
            if test -z "$FSTYPE"; then
              modprobe btrfs
              ${pkgs.btrfs-progs}/bin/mkfs.btrfs ${disk}

              mkdir /nixos
              mount -t btrfs ${disk} /nixos

              ${pkgs.btrfs-progs}/bin/btrfs subvolume create /nixos/root
              ${pkgs.btrfs-progs}/bin/btrfs subvolume create /nixos/persistent
              ${pkgs.btrfs-progs}/bin/btrfs subvolume create /nixos/home

              umount /nixos
            fi
          '';

          # Mock sops secrets paths
          sops.secrets."restic/repo_url".path =
            "${pkgs.writeText "repo_url" "rest:http://test_user:password@127.0.0.1:8000"}";
          sops.secrets."restic/repo_password".path = "${pkgs.writeText "password" "password"}";
          sops.placeholder."restic/s3_access_key".path = "";
          sops.placeholder."restic/s3_secret_key".path = "";
          sops.templates."restic_machine_backup.env".path = "";

          # Networking hostname is required by backup.nix (services.restic.backups.${config.networking.hostName})
          networking.hostName = "machine";

          services.restic.backups.machine.initialize = true;
          services.restic.server.enable = true;
          services.restic.server.htpasswd-file = pkgs.writeText ".htpasswd" ''
            test_user:$2y$05$oV6yBYlNODnad1NbKkAXT.cGaN0ZIpBXE7nbsO9iYt0GvHkNyeEI.
          '';
          custom.backup = {
            enable = true;
            paths = [
              "/var/lib"
              "/home"
            ];
            btrfsSnapshot = {
              "/" = {
                device = disk;
                subvol = "/root";
              };
              "/home" = {
                device = disk;
                subvol = "/home";
              };
              "/var/lib" = {
                device = disk;
                subvol = "/persistent";
              };
            };
          };

          environment.systemPackages = [
            pkgs.btrfs-progs
            pkgs.restic
            pkgs.jq
          ];
        };
    };

  testScript = ''
    machine.start()

    # Create dummy data
    machine.succeed("echo 'important data' > /var/lib/data.txt")
    machine.succeed("mkdir -p /home/test; echo 'important data' > /home/test/data.txt")

    # Start backup service
    machine.succeed("systemctl start restic-backups-machine.service")

    # Verify logs indicate snapshot creation and binding (all in one service now)
    logs = machine.succeed("journalctl -u restic-backups-machine.service")
    assert "Creating snapshot for /root on /dev/vda" in logs
    assert "Bind mounting snapshot to /" in logs
    assert "Cleaning up snapshot for /" in logs

    # Verify backup content
    file_list = machine.succeed("restic-machine ls \"$(restic-machine snapshots --latest 1 -c --json | jq -r .[0].short_id)\" ")
    assert "/var/lib/data.txt" in file_list
    assert "/home/test/data.txt" in file_list

    # Verify cleanup: Wait for snapshot to disappear from the filesystem
    machine.succeed('[ "$(btrfs subvolume list -r -a /)" == "" ]')
  '';
}
