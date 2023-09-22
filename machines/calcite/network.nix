{ pkgs, ...}:

{
  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      # dns = "resolvconf";
    };
  };

  services.resolved = {
    enable = true;
    extraConfig = ''
    [Resolve]
    Domains=~. 
    DNS=127.0.0.1
    '';
    # DNSOverTLS=opportunistic
  };

  # Configure network proxy if necessary
  networking.proxy = {
    allProxy = "socks5://127.0.0.1:7891/";
    httpProxy = "http://127.0.0.1:7890/";
    httpsProxy = "http://127.0.0.1:7890/";
    noProxy = "127.0.0.1,localhost,internal.domain,.coho-tet.ts.net";
  };

  # Enable Tailscale
  services.tailscale.enable = true;
  # services.tailscale.useRoutingFeatures = "both";

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ 41641 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall.trustedInterfaces = [
    "tailscale0"
  ];

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
  # services.xrdp.enable = true;
  # services.xrdp.openFirewall = true;
  # services.xrdp.defaultWindowManager = icewm;
}
