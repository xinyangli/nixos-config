{ config, ... }:
{
  imports = [
    ./hardware-configurations.nix
    ./monitoring.nix
    ./restic.nix
    ./ntfy.nix
  ];

  config = {
    networking.hostName = "thorite";
    networking.useNetworkd = true;
    systemd.network.enable = true;
    systemd.network.networks."10-wan" = {
      matchConfig.MACAddress = "00:51:d3:21:f3:28";
      networkConfig = {
        DHCP = "no";
        Gateway = "23.165.200.1";
        DNSSEC = true;
        DNSOverTLS = true;
        DNS = [
          "8.8.8.8#dns.google"
          "8.8.4.4#dns.google"
        ];
      };
      address = [ "23.165.200.99/24" ];
    };

    commonSettings = {
      auth.enable = true;
      comin.enable = true;
      serverComponents.enable = true;
    };

    custom.mesh-network = {
      ipsec = {
        enable = true;
        commonName = "thorite";
        endpoints = [
          {
            serialNumber = "0";
            addressFamily = "ip4";
            address = "23.165.200.99";
          }
        ];
        interfaces = [ "ens3" ];
      };
      bird.enable = true;
      address = [ "fda1:6cbb:db78::3/128" ];
    };

    nixpkgs.system = "x86_64-linux";
    system.stateVersion = "24.11";
  };
}
