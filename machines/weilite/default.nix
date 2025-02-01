{
  config,
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

  options = {
    node = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };

  config = {
    networking.hostName = "weilite";
    commonSettings = {
      auth.enable = true;
      nix = {
        enable = true;
      };
      comin.enable = true;
    };
    node = {
      mediaDir = "/mnt/nixos/media";
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
      kernelPackages = pkgs.linuxPackages_6_12;
    };

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = [
      pkgs.virtiofsd
      pkgs.intel-gpu-tools
      pkgs.pciutils
    ];

    sops = {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = {
        cloudflare_dns_token = {
          owner = "caddy";
          mode = "400";
        };
        dnspod_dns_token = {
          owner = "caddy";
          mode = "400";
        };
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
        what = "originals";
        where = "/mnt/XinPhotos/originals";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
        wantedBy = [ "immich-server.service" ];
      }
      {
        what = "nixos";
        where = "/mnt/nixos";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
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
        vaapiVdpau
        intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
        intel-media-sdk # QSV up to 11th gen
      ];
    };

    services.openssh.ports = [
      22
      2222
    ];

    services.dae = {
      enable = true;
      configFile = "/var/lib/dae/config.dae";
    };

    services.tailscale = {
      enable = true;
      openFirewall = true;
      permitCertUid = "caddy";
    };

    services.tailscale.derper = {
      enable = true;
      domain = "derper00.namely.icu";
      openFirewall = true;
      verifyClients = true;
    };
    # tailscale derper module use nginx for reverse proxy
    services.nginx.enable = lib.mkForce false;

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.0.0-20240703190432-89f16b99c18e"
          "github.com/caddy-dns/dnspod@v0.0.4"
        ];
        hash = "sha256-EmBKn6QV5JpLXpez7+Gu91tP/sUZxq2DkGPYoAe+2QM=";
      };
      virtualHosts."derper00.namely.icu:8443".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.services.tailscale.derper.port}
      '';
      virtualHosts."weilite.coho-tet.ts.net:8080".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
      # API Token must be added in systemd environment file
      virtualHosts."immich.xinyang.life:8000".extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
      globalConfig = ''
        acme_dns dnspod {env.DNSPOD_API_TOKEN}
      '';
    };

    networking.firewall.allowedTCPPorts = [ 8000 ];

    systemd.services.caddy = {
      serviceConfig = {
        EnvironmentFile = config.sops.secrets.dnspod_dns_token.path;
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
