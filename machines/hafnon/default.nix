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
    comin = {
      enable = true;
      executor = "nix";
    };
    network = {
      # TODO: tailscale is not allowed, so disable this for now
      tailscale.enable = false;
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
  custom.prometheus.exporters.metricsPort = 27280;

  # Root-equivalent privilege scoped to a single named kanidm identity so
  # adding members to `nix-builders` later doesn't widen the trust scope.
  # Required because Hydra dispatches over legacy ssh:// (nix-store --serve
  # --write), which the remote nix-daemon refuses unless the SSH user is in
  # trusted-users. Track NixOS/hydra#688 — when Hydra grows ssh-ng (or any
  # path that doesn't need the remote user trusted), drop this line.
  #
  # SPN form (not bare `nix_access_hydra`) because kanidm-unixd's getpwuid()
  # returns the SPN, and nix-daemon string-compares against that.
  nix.settings.trusted-users = [ "nix_access_hydra@${config.my-lib.settings.idpUrl}" ];

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

        iifname "ens20" ct mark set 20
        iifname "ens21" ct mark set 21
      }

      chain output {
        type route hook output priority mangle; policy accept;

        ct mark 20 meta mark set 20
        ct mark 21 meta mark set 21
      }
    }
  '';

  systemd.network.netdevs = {
    "20-dummy20" = {
      netdevConfig = {
        Name = "dummy20";
        Kind = "dummy";
      };
    };
    "21-dummy21" = {
      netdevConfig = {
        Name = "dummy21";
        Kind = "dummy";
      };
    };
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = false;
    networks = {
      "10-ens20" = {
        matchConfig = {
          MACAddress = "bc:24:11:8f:df:b5";
        };
        networkConfig = {
          DHCP = "ipv6";
          IPv6AcceptRA = false;
          IPv6SendRA = false;
          DHCPPrefixDelegation = false;
        };
        dhcpV6Config = {
          WithoutRA = "solicit";
          UseAddress = false;
          UseDelegatedPrefix = true;
          PrefixDelegationHint = "::/64";
        };
        routes = [
          {
            Gateway = "fe80::1";
            Destination = "::/0";
            GatewayOnLink = true;
            Metric = 100;
          }
          {
            Destination = "::/0";
            Gateway = "fe80::1";
            GatewayOnLink = true;
            Table = 120;
          }
        ];
        routingPolicyRules = [
          {
            Family = "ipv6";
            FirewallMark = 20;
            Table = 120;
            Priority = 1020;
          }
        ];
      };
      "10-ens21" = {
        matchConfig = {
          MACAddress = "bc:24:11:00:4c:dd";
        };
        networkConfig = {
          DHCP = "ipv6";
          IPv6AcceptRA = false;
          IPv6SendRA = false;
          DHCPPrefixDelegation = false;
        };
        dhcpV6Config = {
          WithoutRA = "solicit";
          UseAddress = false;
          UseDelegatedPrefix = true;
          PrefixDelegationHint = "::/64";
        };
        routes = [
          {
            Gateway = "fe80::1";
            Destination = "::/0";
            GatewayOnLink = true;
            Metric = 200;
          }
          {
            Destination = "::/0";
            Gateway = "fe80::1";
            GatewayOnLink = true;
            Table = 121;
          }
        ];
        routingPolicyRules = [
          {
            Family = "ipv6";
            FirewallMark = 21;
            Table = 121;
            Priority = 1020;
          }
        ];
      };
      "20-dummy20" = {
        matchConfig.Name = "dummy20";
        linkConfig.RequiredForOnline = false;
        networkConfig = {
          DHCPPrefixDelegation = true;
          IPv6SendRA = false;
        };

        dhcpPrefixDelegationConfig = {
          UplinkInterface = "ens20";
          SubnetId = 0;
          Announce = false;
          Token = "::1";
        };
      };

      "21-dummy21" = {
        matchConfig.Name = "dummy21";
        linkConfig.RequiredForOnline = false;
        networkConfig = {
          DHCPPrefixDelegation = true;
          IPv6SendRA = false;
        };

        dhcpPrefixDelegationConfig = {
          UplinkInterface = "ens21";
          SubnetId = 0;
          Announce = false;
          Token = "::1";
        };
      };
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
