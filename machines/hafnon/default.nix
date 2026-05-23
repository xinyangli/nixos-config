{ config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
  ];

  services.qemuGuest.enable = true;
  boot.initrd.systemd.enable = true;
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot";
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # FIXME: https://github.com/Mic92/sops-nix/issues/764
  sops.environment.HOME = "/var/empty";

  system.nixos-init.enable = true;
  system.etc.overlay.enable = true;

  commonSettings = {
    auth.enable = true;
    auth.enableBuilder = true;
    nix = {
      enable = true;
    };
    comin.enable = true;
    network = {
      localdns = {
        enable = true;
        fallbackDNS = ''
          policy.add(policy.all(policy.FORWARD({
            "100.112.247.225"
          })))
        '';
      };
      enableProxy = false;
    };
    serverComponents.enable = true;
  };

  # Root-equivalent privilege scoped to a single named kanidm identity so
  # adding members to `nix-builders` later doesn't widen the trust scope.
  # Required because Hydra dispatches over legacy ssh:// (nix-store --serve
  # --write), which the remote nix-daemon refuses unless the SSH user is in
  # trusted-users. Track NixOS/hydra#688 — when Hydra grows ssh-ng (or any
  # path that doesn't need the remote user trusted), drop this line.
  nix.settings.trusted-users = [ "nix_access_hydra" ];

  system.stateVersion = "26.05";
  time.timeZone = "Asia/Shanghai";

  # TODO: tailscale is not allowed, so disable this for now
  # custom.prometheus.exporters = {
  #   enable = true;
  #   blackbox = {
  #     enable = true;
  #   };
  #   node = {
  #     enable = true;
  #   };
  # };
  #
  # custom.monitoring = {
  #   promtail.enable = true;
  # };

  services.tailscale.enable = false;
  networking = {
    useNetworkd = true;
    hostName = "hafnon";
  };

  custom.mesh-network = {
    ipsec = {
      enable = true;
      commonName = "hafnon";
      port = 27201;
      endpoints = [
        {
          serialNumber = "0";
          addressFamily = "ip4";
          address = "homo.j8.network";
        }
      ];
      interfaces = [ "ens19" ];
    };
    bird.enable = true;
    address = [ "fda1:6cbb:db78::6/128" ];
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = false;
    networks = {
      "10-lan" = {
        matchConfig = {
          MACAddress = "bc:24:11:e5:4f:f7";
        };
        address = [ "100.112.247.229/27" ];
        gateway = [ "100.112.247.225" ];
        dns = [ "100.112.247.225" ];

        networkConfig = {
          DHCP = "ipv6";
          IPv6AcceptRA = true;
        };
      };
    };
  };
}
