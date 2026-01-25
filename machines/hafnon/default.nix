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
    nix = {
      enable = true;
    };
    comin.enable = true;
    network = {
      localdns = {
        enable = true;
        fallbackDNS = ''
          policy.add(policy.all(policy.FORWARD({
            "100.100.100.100", "100.100.101.101",
          })))
        '';
      };
      enableProxy = false;
    };
    serverComponents.enable = true;
  };
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

  systemd.network = {
    enable = true;
    wait-online.anyInterface = false;
    networks = {
      "10-wan" = {
        matchConfig = {
          MACAddress = "bc:24:11:97:b8:ce";
        };
        address = [ "10.10.10.2/16" ];
        gateway = [ "10.10.0.1" ];

        # Optional: Add DNS servers if you haven't defined them globally
        networkConfig = {
          IPv6AcceptRA = false;
        };
      };
    };
  };
}
