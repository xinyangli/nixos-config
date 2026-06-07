{
  pkgs,
  lib,
  ...
}:
{
  imports = [ ];

  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = true;
        RoamThreshold = -62;
        RoamThreshold5G = -65;
        RoamRetryInterval = 15;
        CriticalRoamThreshold = -70;
        CriticalRoamThreshold5G = -70;
      };
      Scan = {
        DisablePeriodicScan = false;
      };
      Network = {
        EnableIPv6 = true;
        NameResolvingService = "resolvconf";
      };
      Settings = {
        AutoConnect = true;
      };
    };
  };
  systemd.network.networks."99-wireless-client-dhcp".enable = false;
  systemd.network.networks."10-en" = {
    matchConfig = {
      Name = "en*";
    };
    networkConfig = {
      DHCP = true;
    };
    dhcpV4Config.RouteMetric = 100;
    ipv6AcceptRAConfig.RouteMetric = 100;
    dhcpPrefixDelegationConfig.RouteMetric = 100;
  };

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 5000 ];
  # Use nftables to manager firewall
  networking.nftables.enable = true;

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  programs.kdeconnect = {
    enable = true;
  };

  networking.useNetworkd = true;
  networking.resolvconf.enable = true;
  services.resolved.enable = false;
  custom.mesh-network = {
    ipsec = {
      enable = true;
      commonName = "cinnabar";
      endpoints = [
        {
          serialNumber = "0";
          addressFamily = "ip4";
          address = null;
        }
      ];
      interfaces = [ ];
    };
    bird.enable = true;
    address = [ "fda1:6cbb:db78::5/128" ];
    gost.enable = true;
  };
}
