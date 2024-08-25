{
  inputs,
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:

with lib;

{
  imports = [
    inputs.sops-nix.nixosModules.sops
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
      kernelModules = [ "kvm-intel" ];
    };

    environment.systemPackages = [ pkgs.virtiofsd ];

    sops = {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = {
        cloudflare_dns_token = {
          owner = "caddy";
          mode = "400";
        };
      };
    };

    custom.prometheus = {
      enable = true;
    };

    systemd.mounts = [
      {
        what = "immich";
        where = "/mnt/XinPhotos/immich";
        type = "virtiofs";
        options = "rw";
        wantedBy = [ "immich-server.service" ];
      }
      {
        what = "originals";
        where = "/mnt/XinPhotos/originals";
        type = "virtiofs";
        options = "ro,nodev,nosuid";
        wantedBy = [ "immich-server.service" ];
      }
    ];

    services.openssh.ports = [
      22
      2222
    ];

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
      package = pkgs.caddy.withPlugins {
        caddyModules = [
          {
            repo = "github.com/caddy-dns/cloudflare";
            version = "89f16b99c18ef49c8bb470a82f895bce01cbaece";
          }
        ];
        vendorHash = "sha256-fTcMtg5GGEgclIwJCav0jjWpqT+nKw2OF1Ow0MEEitk=";
      };
      virtualHosts."weilite.coho-tet.ts.net:8080".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
      # API Token must be added in systemd environment file
      virtualHosts."immich.xinyang.life:8000".extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
    };

    networking.firewall.allowedTCPPorts = [ 8000 ];

    systemd.services.caddy = {
      serviceConfig = {
        EnvironmentFile = config.sops.secrets.cloudflare_dns_token.path;
      };
    };

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
