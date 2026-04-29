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
    package = pkgs.wireshark-qt;
  };

  programs.kdeconnect = {
    enable = true;
  };

  services.cloudflare-warp = {
    enable = true;
    openFirewall = true;
  };
}
