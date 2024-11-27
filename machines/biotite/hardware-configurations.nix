{ config, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            boot = config.diskPartitions.grubMbr;
            root = config.diskPartitions.btrfs;
          };
        };
      };
    };
  };
}
