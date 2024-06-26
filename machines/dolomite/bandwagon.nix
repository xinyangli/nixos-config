{ config, lib, pkgs, modulesPath, ... }:
let
  cfg = config.isBandwagon;
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];


  options = {
    isBandwagon = lib.mkEnableOption "Bandwagon instance";
  };

  config = lib.mkIf cfg {
    boot.initrd.availableKernelModules = [ "ata_piix" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];

    fileSystems."/" =
      { device = "/dev/disk/by-label/NIXROOT";
        fsType = "xfs";
      };

    fileSystems."/boot" =
      { device = "/dev/disk/by-label/NIXBOOT";
        fsType = "vfat";
      };

    swapDevices = [ ];

    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";
    networking.useDHCP = false;
    networking.interfaces.ens18.useDHCP = true;
    networking.interfaces.ens19.useDHCP = true;
  };
}
