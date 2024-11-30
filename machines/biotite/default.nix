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
    matchConfig.MACAddress = "b6:20:0d:9a:6c:34";
    networkConfig = {
      DHCP = "ipv4";
      IPv6SendRA = true;
    };
    address = [ "2a03:4000:4a:148::1/64" ];
  };

  commonSettings = {
    auth.enable = true;
    autoupgrade.enable = true;
  };

  users.users.root.hashedPassword = "$y$j9T$NToEZWJBONjSgRnMd9Ur9/$o6n7a9b8eUILQz4d37oiHCCVnDJ8hZTZt.c.37zFfU.";

  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
