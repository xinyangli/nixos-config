{ pkgs, ...}:

{
  # Enable networking
  networking = {
    nameservers = [ "127.0.0.1" "::1" ];
    networkmanager = {
      enable = true;
    };
    resolvconf.useLocalResolver = true;
  };

  # Enable Tailscale
  services.tailscale.enable = true;
  # services.tailscale.useRoutingFeatures = "both";

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.firewall.allowedUDPPorts = [ 41641 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  programs.steam.remotePlay.openFirewall = true;

  # Add gsconnect, open firewall
  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark-qt;
  };

  # services.gnome.gnome-remote-desktop.enable = true;
}