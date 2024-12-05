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

  config = {
    networking.hostName = "weilite";
    commonSettings = {
      auth.enable = true;
      nix = {
        enable = true;
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

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = [ pkgs.virtiofsd ];

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
        what = "immich";
        where = "/mnt/XinPhotos/immich";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
        wantedBy = [ "immich-server.service" ];
      }
      {
        what = "originals";
        where = "/mnt/XinPhotos/originals";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
        wantedBy = [ "immich-server.service" ];
      }
      {
        what = "restic";
        where = "/var/lib/restic";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
        wantedBy = [ "restic-rest-server.service" ];
      }
      {
        what = "ocis";
        where = "/var/lib/ocis";
        type = "virtiofs";
        options = "rw,nodev,nosuid";
        wantedBy = [ "ocis.service" ];
      }
    ];

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
        caddyModules = [
          {
            repo = "github.com/caddy-dns/cloudflare";
            version = "89f16b99c18ef49c8bb470a82f895bce01cbaece";
          }
          {
            repo = "github.com/caddy-dns/dnspod";
            version = "1fd4ce87e919f47db5fa029c31ae74b9737a58af";
          }
        ];
        vendorHash = "sha256-OhOeU2+JiJyIW9WdCYq98OKckXQZ9Fn5zULz0aLsXMI=";
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
