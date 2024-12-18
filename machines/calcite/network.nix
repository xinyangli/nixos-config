{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ];

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
  };

  services.resolved = {
    enable = true;
    extraConfig = ''
      Cache=no
    '';
  };

  # Enable Tailscale
  services.tailscale.enable = true;
  # services.tailscale.useRoutingFeatures = "both";

  services.dae.enable = true;
  services.dae.configFile = "/var/lib/dae/config.dae";
  systemd.services.dae.after = lib.mkIf (config.networking.networkmanager.enable) [
    "NetworkManager-wait-online.service"
  ];

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
