{ pkgs, ... }:
{
  networking = {
    interfaces = {
      eth0.useDHCP = true;
      eth0.ipv6.addresses = [
        {
          address = "2a01:4f8:c17:345f::1";
          prefixLength = 64;
        }
      ];
    };
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    nameservers = [ ];
  };
}
