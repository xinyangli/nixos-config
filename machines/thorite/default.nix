{ ... }:
{
  imports = [
    ./hardware-configurations.nix
  ];

  networking.hostName = "thorite";
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "00:51:d3:21:f3:28";
    networkConfig = {
      DHCP = "no";
      Gateway = "23.165.200.1";
    };
    address = [ "23.165.200.99/24" ];
  };

  nixpkgs.system = "x86_64-linux";

  system.stateVersion = "24.11";

  commonSettings = {
    auth.enable = true;
    autoupgrade.enable = true;
  };

  users.users.root.hashedPassword = "$y$j9T$NToEZWJBONjSgRnMd9Ur9/$o6n7a9b8eUILQz4d37oiHCCVnDJ8hZTZt.c.37zFfU.";
}
