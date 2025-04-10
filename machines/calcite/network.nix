{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.my-lib.settings)
    internalDomain
    ;
in
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

  # Enable Tailscale
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-dns=false" ];
  };
  # services.tailscale.useRoutingFeatures = "both";

  # services.dae.enable = true;
  # services.dae.configFile = "/var/lib/dae/config.dae";
  # systemd.services.dae.after = lib.mkIf (config.networking.networkmanager.enable) [
  #   "NetworkManager-wait-online.service"
  # ];
  #
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
