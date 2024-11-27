{
  size = "100%";
  content = {
    type = "btrfs";
    extraArgs = [ "-f" ]; # Override existing partition
    # Subvolumes must set a mountpoint in order to be mounted,
    # unless their parent is mounted
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
          "compress=zstd"
          "noatime"
          # Lots of dbs in /var/lib, let's disable cow
          "nodatacow"
        ];
        mountpoint = "/var/lib";
      };
      # Subvolume for the swapfile
      "/swap" = {
        mountpoint = "/.swapvol";
        swap = {
          swapfile.size = "2G";
        };
      };
    };

    mountpoint = "/partition-root";
  };
}
