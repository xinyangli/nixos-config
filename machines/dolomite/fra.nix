# Do not modify this file!  It was generated by ‘nixos-generate-co
# and may be overwritten by future invocations.  Please make chang
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 2 * 1024;
    }
  ];

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
    device = "/dev/sda";
  };
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "00:16:3c:d2:7b:64";
    networkConfig = {
      DHCP = "no";
      Gateway = "185.217.108.1";
      DNSSEC = true;
      DNSOverTLS = true;
      DNS = [
        "8.8.8.8#dns.google"
        "8.8.4.4#dns.google"
      ];
    };
    address = [ "185.217.108.59/24" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
