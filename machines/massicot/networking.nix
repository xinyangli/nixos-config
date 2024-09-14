{ pkgs, ... }:
{
  networking.useNetworkd = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "96:00:02:68:7d:2d";
    networkConfig.DHCP = "ipv4";
    networkConfig.Gateway = "fe80::1";
    address = [
      "2a01:4f8:c17:345f::3/64"
    ];
  };
}
