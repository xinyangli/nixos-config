{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./services/hass.nix ];

  commonSettings = {
    nix.enable = true;
    auth.enable = true;
    comin.enable = true;
    network.enableProxy = false;
    serverComponents.enable = true;
  };

  nixpkgs.overlays = [
    # Workaround https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  nixpkgs.config.allowUnfree = true;

  networking.firewall.allowedTCPPorts = [ 8443 ];
  # mDNS unicast replies for matter-server commissioning. conntrack does not
  # relate the multicast query to the unicast response (different dst tuple),
  # so without this the default INPUT chain drops them.
  networking.firewall.allowedUDPPorts = [ 5353 ];

  environment.systemPackages = with pkgs; [
    git
    libraspberrypi
    raspberrypi-eeprom
  ];

  system.stateVersion = "24.05";

  networking = {
    hostName = "raspite";
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
  };

  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.EnableNetworkConfiguration = true;
      Settings.AutoConnect = true;
    };
  };

  systemd.network = {
    networks."10-eth" = {
      matchConfig.MACAddress = "dc:a6:32:a8:09:cf";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      dhcpV4Config.RouteMetric = 100;
      ipv6AcceptRAConfig.RouteMetric = 100;
      linkConfig.RequiredForOnline = "routable";
    };
  };
  time.timeZone = "Asia/Shanghai";
}
