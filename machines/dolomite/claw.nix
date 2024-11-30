{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  config = {
    boot.initrd.availableKernelModules = [
      "uhci_hcd"
      "virtio_blk"
      "ahci"
      "ata_piix"
      "virtio_pci"
      "xen_blkfront"
      "vmw_pvscsi"
    ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];
    boot.loader.grub = {
      enable = true;
      device = "/dev/vda";
    };

    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };

    networking.useNetworkd = true;
    systemd.network.enable = true;
    systemd.network.networks."10-wan" = {
      matchConfig.MACAddress = "00:16:3e:0a:ec:45";
      networkConfig.DHCP = "ipv4";
      dhcpV4Config = {
        UseDNS = true;
      };
    };

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  };
}
