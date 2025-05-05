{
  disko.devices = {
    disk = {
      ssd1 = {
        type = "disk";
        device = "/dev/disk/by-path/pci-0004:49:00.0-sas-exp0x500e004aaaaaaa1f-phy1-lun-0";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot0";
              };
            };
            system_p1 = {
              size = "100%";
            };
          };
        };
      };
      ssd2 = {
        type = "disk";
        device = "/dev/disk/by-path/pci-0004:49:00.0-sas-exp0x500e004aaaaaaa1f-phy2-lun-0";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot1";
              };
            };
            system_p2 = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-d raid1"
                  "/dev/disk/by-partlabel/disk-ssd1-system_p1"
                ];
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  # Subvolume name is the same as the mountpoint
                  "/home" = {
                    mountOptions = [ "compress=zstd" ];
                    mountpoint = "/home";
                  };
                  # Parent is not mounted so the mountpoint must be set
                  "/nix" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                  "/persistent" = {
                    mountOptions = [
                      "noatime"
                      # Lots of dbs in /var/lib, let's disable cow
                      "nodatacow"
                    ];
                    mountpoint = "/var/lib";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
