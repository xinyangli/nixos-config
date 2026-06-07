{ config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./services
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = lib.mkForce [ ];
    mirroredBoots = [
      {
        devices = [
          "/dev/disk/by-partlabel/disk-ssd1-system_p1"
        ];
        path = "/boot0";
      }
      {
        devices = [
          "/dev/disk/by-partlabel/disk-ssd2-system_p2"
        ];
        path = "/boot1";
      }
    ];
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # FIXME: https://github.com/Mic92/sops-nix/issues/764
  sops.environment.HOME = "/var/empty";

  services.userborn.enable = true;

  commonSettings = {
    auth.enable = true;
    nix = {
      enable = true;
      signing.enable = true;
    };
    comin = {
      enable = true;
      executor = "nix";
      metricsPort = 18080;
    };
    network.localdns.enable = true;
    serverComponents.enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 18080 ];

  system.stateVersion = "25.05";
  time.timeZone = "Asia/Shanghai";

  nix.settings = {
    max-jobs = 8;
    cores = 16;
  };

  custom.prometheus.exporters = {
    enable = true;
    blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
    node = {
      enable = true;
    };
  };

  services.caddy.virtualHosts."http://agate.10118244.xyz:18080".extraConfig = ''
    handle_path /prometheus/blackbox {
      rewrite * /probe
      reverse_proxy http://127.0.0.1:9115
    }
  '';

  custom.monitoring = {
    fluent-bit.enable = true;
  };

  networking = {
    useNetworkd = true;
    hostName = "agate";
  };
  systemd.network = {
    enable = true;
    networks = {
      "10-wan" = {
        matchConfig.MACAddress = "80:b5:75:86:9e:c8";
        networkConfig = {
          DHCP = "ipv4";
        };
      };
    };
  };

  custom.mesh-network = {
    ipsec = {
      enable = true;
      commonName = "agate";
      endpoints = [
        {
          serialNumber = "0";
          addressFamily = "ip4";
          address = "agate_home.xiny.li";
        }
      ];
      interfaces = [ "enahisic2i2" ];
    };
    bird.enable = true;
    address = [ "fda1:6cbb:db78::7/128" ];
  };
}
