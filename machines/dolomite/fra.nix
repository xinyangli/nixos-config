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
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-path/pci-0000:00:04.0-scsi-0:0:0:0";
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

  nix.gc = {
    dates = "daily";
    options = "--delete-older-than 1d";
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

  custom.mesh-network = {
    ipsec = {
      enable = true;
      commonName = "fra-00";
      endpoints = [
        {
          serialNumber = "0";
          addressFamily = "ip4";
          address = "185.217.108.59";
        }
      ];
      interfaces = [ "ens0" ];
    };
    bird = {
      enable = true;
      routes = [ "fda1:6cbb:db78::1/128" ];
    };
  };
}
