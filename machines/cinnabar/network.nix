{
  pkgs,
  lib,
  ...
}:
{
  imports = [ ];

  networking = {
    networkmanager = {
      enable = true;
      dns = lib.mkForce "default";
      settings = {
        main = {
          rc-manager = "resolvconf";
        };
      };
      plugins = [
        pkgs.networkmanager-openconnect
      ];
    };
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
      interfaces = [
        "wlo1"
        "enp84s0"
      ];
    };
    bird = {
      enable = true;
      routes = [ "fda1:6cbb:db78::5/128" ];
    };
  };

  services.cloudflare-warp = {
    enable = true;
    openFirewall = true;
  };
}
