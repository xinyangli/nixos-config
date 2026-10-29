{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
  ];

  services.qemuGuest.enable = true;
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
    secrets."hydra/builder_token" = {
      owner = "hydra-builder";
      mode = "0400";
    };
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
    comin = {
      enable = true;
      executor = "nix";
    };
    network = {
      # TODO: tailscale is not allowed, so disable this for now
      tailscale.enable = false;
      localdns = {
        enable = true;
        mainlandDNS = ''
          policy.add(policy.suffix(policy.FORWARD({
            "10.10.0.2"
          }), chinaDomains))
        '';
      };
    };
    serverComponents.enable = true;
  };
  custom.prometheus.exporters.metricsPort = 27280;

  services.hydra-builder = {
    enable = true;
    queueRunnerAddr = "http://[fda1:6cbb:db78::7]:50051";
    authorizationFile = config.sops.secrets."hydra/builder_token".path;
    settings = {
      maxJobs = 3;
      systems = [ "x86_64-linux" ];
      supportedFeatures = [
        "nixos-test"
        "big-parallel"
        "benchmark"
      ];
    };
  };

  system.stateVersion = "26.05";
  time.timeZone = "Asia/Shanghai";

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

  # conntrack for ipv6 mwan
  networking.nftables.ruleset = ''
    table inet wan_mark {
      chain prerouting {
        type filter hook prerouting priority mangle; policy accept;

        iifname "ens18" ct mark set 18
        iifname "ens19" ct mark set 19
      }

      chain output {
        type route hook output priority mangle; policy accept;

        ct mark 18 meta mark set 18
        ct mark 19 meta mark set 19
      }
    }
  '';

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;
    networks = {
      "10-wan1" = {
        matchConfig = {
          MACAddress = "bc:24:11:e5:4f:f7";
        };
        address = [ "100.112.247.229/27" ];
        gateway = [ "100.112.247.225" ];

        networkConfig = {
          DHCP = "ipv6";
          IPv6AcceptRA = true;
        };
        ipv6AcceptRAConfig = {
          UseDNS = false;
        };
      };
      "10-wan2" = {
        matchConfig = {
          MACAddress = "bc:24:11:97:b8:ce";
        };
        address = [ "10.10.10.2/16" ];
        # gateway = [ "10.10.0.3" ];
        dns = [ "10.10.0.3" ];
        networkConfig = {
          DHCP = false;
          IPv6AcceptRA = true;
        };
        ipv6AcceptRAConfig = {
          UseDNS = false;
        };
      };
    };
  };
}
