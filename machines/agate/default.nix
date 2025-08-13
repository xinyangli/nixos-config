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
  users.users.root.hashedPassword = "$y$j9T$vgLUF3/R0RJpDu7e22fSW.$CPomHsuRziERtNGUnnMZZDQG.Vj7LCe5PUOSbvkwSV3";

  commonSettings = {
    auth.enable = true;
    nix = {
      enable = true;
    };
    comin.enable = true;
    network.localdns.enable = true;
    serverComponents.enable = true;
  };
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
    };
    node = {
      enable = true;
    };
  };

  custom.monitoring = {
    promtail.enable = true;
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
}
