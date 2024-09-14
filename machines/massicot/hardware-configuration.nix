{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AC27-D9D6";
    fsType = "vfat";
  };
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "xen_blkfront"
  ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = {
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_35068215-part1";
    fsType = "ext4";
  };

  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-id/scsi-0HC_Volume_101302395";
    fsType = "btrfs";
    options = [
      "subvol=storage"
      "compress=zstd"
      "noatime"
    ];
  };
}
