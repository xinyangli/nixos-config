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
      dns = "default";
      settings = {
        main = {
          rc-manager = "resolvconf";
        };
      };
    };
  };

  networking.resolvconf = {
    enable = true;
    dnsExtensionMechanism = false;
    useLocalResolver = false;
  };

  services.kresd = {
    enable = true;
    listenPlain = [ ];
    extraConfig = ''
      log_level("notice")
      net.listen('127.0.0.1', 53)
      modules = { 'hints > iterate', 'stats', 'predict' }
      cache.size = 100 * MB
      trust_anchors.remove(".")
      policy.add(policy.all(policy.TLS_FORWARD( {
        { "8.8.8.8", hostname="dns.google" } })))
    '';
      # policy.add(policy.suffix(policy.FORWARD({ "100.100.100.100" }), policy.todnames({ 'coho-tet.ts.net' })))
  };

  # Enable Tailscale
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-dns=false" ];
  };
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
