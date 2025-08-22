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

  # Open ports in the firewall.
  networking.firewall.enable = true;
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
