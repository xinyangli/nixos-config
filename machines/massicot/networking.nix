{
  networking = {
    interfaces = {
      eth0.ipv6.addresses = [{
        address = "2a01:4f8:c17:345f::1";
        prefixLength = 64;
      }];
    };
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    nameservers = [ "2a00:1098:2b::1" "2a00:1098:2c::1" "2a01:4f9:c010:3f02::1"];
  };
}