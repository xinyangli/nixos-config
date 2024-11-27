{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hardware-configurations.nix ];

  networking.hostName = "biotite";
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "00:16:3e:0a:ec:45";
    networkConfig.DHCP = "ipv4";
    dhcpV4Config = {
      UseDNS = true;
    };
  };

  commonSettings = {
    auth.enable = true;
    autoupgrade.enable = true;
  };

  users.users.root.hashedPassword = "$y$j9T$NToEZWJBONjSgRnMd9Ur9/$o6n7a9b8eUILQz4d37oiHCCVnDJ8hZTZt.c.37zFfU.";

  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
