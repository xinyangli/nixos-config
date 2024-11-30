{
  imports = [
    ./hardware-configurations.nix
    ./monitoring.nix
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

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    commonSettings = {
      auth.enable = true;
    };

    nixpkgs.system = "x86_64-linux";
    system.stateVersion = "24.11";

    users.users.root.hashedPassword = "$y$j9T$NToEZWJBONjSgRnMd9Ur9/$o6n7a9b8eUILQz4d37oiHCCVnDJ8hZTZt.c.37zFfU.";
  };
}
