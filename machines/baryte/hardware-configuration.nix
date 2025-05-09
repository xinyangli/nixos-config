{ config, modulesPath, ... }:
{
  imports = [ ];

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
