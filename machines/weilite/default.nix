{ config, pkgs, lib, modulesPath, ... }:

with lib;

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  config = {
    networking.hostName = "weilite";
    commonSettings = {
      auth.enable = true;
      nix = {
        enable = true;
        enableMirrors = true;
      };
    };

    boot = {
      loader =  {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "usb_storage" "sd_mod" ];
      kernelModules = [ "kvm-intel" ];
    };

    environment.systemPackages = [
      pkgs.virtiofsd
    ];

    systemd.mounts = [
      { what = "XinPhotos";
        where = "/mnt/XinPhotos";
        type = "virtiofs";
        wantedBy = [ "immich-server.service" ];
      }
    ];

    services.openssh.ports = [ 22 2222 ];

    services.immich = {
      enable = true;
      mediaLocation = "/mnt/XinPhotos/immich";
      host = "127.0.0.1";
      port = 3001;
      openFirewall = true;
      machine-learning.enable = false;
      environment = {
        IMMICH_MACHINE_LEARNING_ENABLED = "false";
      };
    };

    services.dae = {
      enable = true;
      configFile = "/var/lib/dae/config.dae";
    };

    services.tailscale = {
      enable = true;
      openFirewall = true;
      permitCertUid = "caddy";
    };

    services.caddy = {
      enable = true;
      virtualHosts."weilite.coho-tet.ts.net:8080".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
    };

    time.timeZone = "Asia/Shanghai";
  
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
    };

    fileSystems."/boot" = {
      device = "/dev/sda1";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

    system.stateVersion = "24.11";
  };
}
