{
  pkgs,
  ...
}:
{
  imports = [ ];

  networking = {
    networkmanager = {
      enable = true;
      dns = "default";
      settings = {
        main = {
          rc-manager = "resolvconf";
        };
      };
    };
  };

  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-routes" ];
  };

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 3389 ];
  networking.firewall.allowedUDPPorts = [
    3389
    41641
  ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  # Use nftables to manager firewall
  networking.nftables.enable = true;

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark-qt;
  };

  programs.kdeconnect = {
    enable = true;
    package = pkgs.valent;
  };
}
