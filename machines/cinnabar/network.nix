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
  };

  services.cloudflare-warp = {
    enable = true;
    openFirewall = true;
  };
}
