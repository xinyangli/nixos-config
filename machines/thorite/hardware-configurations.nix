{ config, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
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
  disko.devices.disk.main.imageSize = "10G";

  boot.initrd.availableKernelModules = [
    "uhci_hcd"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
    "ahci"
    "ata_piix"
    "virtio_pci"
    "xen_blkfront"
    "vmw_pvscsi"
  ];

  boot.loader.grub = {
    enable = true;
  };

  boot.kernelModules = [ "kvm-intel" ];
}
