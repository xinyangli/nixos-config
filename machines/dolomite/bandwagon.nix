{
  config,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  config = {
    boot.initrd.availableKernelModules = [
      "ata_piix"
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];
    boot.loader.grub.enable = true;
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
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
    systemd.network.networks."10-wan" = {
      matchConfig.MACAddress = "ens18";
      networkConfig.DHCP = "ipv4";
      dhcpV4Config = {
        UseDNS = false;
      };
    };
    systemd.network.networks."20-lan" = {
      matchConfig.MACAddress = "ens19";
      networkConfig.DHCP = "ipv4";
    };
    services.resolved.enable = true;

    services.sing-box.settings.dns.strategy = "ipv4_only";

    custom.mesh-network = {
      ipsec = {
        enable = true;
        commonName = "la-00";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = "67.230.168.47";
          }
        ];
        interfaces = [ "ens18" ];
      };
      bird = {
        enable = true;
        routes = [ "fda1:6cbb:db78::2/128" ];
      };
    };
  };
}
