{ lib, ... }:
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

  users.users.root.hashedPassword = "$y$j9T$vgLUF3/R0RJpDu7e22fSW.$CPomHsuRziERtNGUnnMZZDQG.Vj7LCe5PUOSbvkwSV3";

  commonSettings = {
    auth.enable = true;
    nix = {
      enable = true;
    };
    comin.enable = true;
    network.localdns.enable = true;
  };
  system.stateVersion = "25.05";
  time.timeZone = "Asia/Shanghai";

  nix.settings = {
    max-jobs = 8;
    cores = 16;
    substituters = [ "https://cache.ngi0.nixos.org/" ];
    trusted-public-keys = [ "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA=" ];
  };

  nixpkgs.config.contentAddressedByDefault = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
    permitCertUid = "caddy";
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
}
