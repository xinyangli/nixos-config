{ pkgs, ...}:

{
  imports = [
    ../sing-box.nix
  ];

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
  };

  services.resolved = {
    enable = true;
  };

  # Enable Tailscale
  services.tailscale.enable = true;
  # services.tailscale.useRoutingFeatures = "both";

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ 41641 ];
  networking.firewall.trustedInterfaces = [
    "tun0"
    "tailscale0"
  ];
  # Use nftables to manager firewall
  networking.nftables.enable = true;

  # Add gsconnect, open firewall
  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark-qt;
  };
}
