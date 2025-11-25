{
  pkgs,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./services
  ];

  config = {
    networking = {
      hostName = "weilite";
      useNetworkd = true;
    };
    systemd.network = {
      enable = true;
      networks = {
        "10-wan" = {
          matchConfig.MACAddress = "52:54:00:db:23:d0";
          networkConfig.DHCP = "ipv4";
        };
      };
    };
    commonSettings = {
      auth.enable = true;
      nix = {
        enable = true;
      };
      comin.enable = true;
      network.localdns.enable = true;
      serverComponents.enable = true;
    };

    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      initrd.availableKernelModules = [
        "uhci_hcd"
        "ehci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [
        "kvm-intel"
      ];
    };

    nixpkgs.config.allowUnfree = true;
    nixpkgs.hostPlatform = "x86_64-linux";

    environment.systemPackages = [
      pkgs.virtiofsd
      pkgs.intel-gpu-tools
      pkgs.pciutils
    ];

    sops = {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = {
        "restic/localpass" = {
          owner = "restic";
        };
      };
    };

    custom.prometheus.exporters = {
      enable = true;
      blackbox = {
        enable = true;
      };
      node = {
        enable = true;
      };
    };

    custom.monitoring = {
      promtail.enable = true;
    };

    systemd.mounts = [
      {
        what = "nixos";
        where = "/mnt/nixos";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
      }
      {
        what = "originals";
        where = "/mnt/photos/xin/originals";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
        wantedBy = [ "immich-server.service" ];
      }
      {
        what = "/mnt/nixos/ocis";
        where = "/var/lib/ocis";
        options = "bind";
        after = [ "mnt-nixos.mount" ];
        wantedBy = [ "ocis.service" ];
      }
      {
        what = "/mnt/nixos/restic";
        where = "/var/lib/restic";
        options = "bind";
        after = [ "mnt-nixos.mount" ];
        wantedBy = [ "restic-rest-server.service" ];
      }
      {
        what = "/mnt/nixos/immich";
        where = "/var/lib/immich";
        options = "bind";
        after = [ "mnt-nixos.mount" ];
        wantedBy = [ "immich-server.service" ];
      }
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        libva-vdpau-driver
        intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      ];
    };

    services.tailscale.derper = {
      enable = true;
      domain = "derper00.10118244.xyz";
      openFirewall = true;
      verifyClients = true;
    };
    # tailscale derper module use nginx for reverse proxy
    services.nginx.enable = lib.mkForce false;

    time.timeZone = "Asia/Shanghai";

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
    };

    fileSystems."/boot" = {
      device = "/dev/sda1";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };

    system.stateVersion = "24.11";
  };
}
