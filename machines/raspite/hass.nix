{ config, pkgs, ... }: {
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "default_config"
      "esphome"
      "met"
      "radio_browser"
    ];
    openFirewall = false;
    config = {
      default_config = {};
      http = {
        server_host = "::1";
        base_url = "raspite.local:1000";
        use_x_forward_for = true;
        trusted_proxies = [
          "::1"
        ];
      };
    };
  };

  services.esphome = {
    enable = true;
    openFirewall = false;
  };

  users.groups.dialout.members = config.users.groups.wheel.members;

  environment.systemPackages = with pkgs; [
    zigbee2mqtt
  ];

  networking.firewall.allowedTCPPorts = [ 1000 1001 ];

  services.caddy = {
    enable = true; 
    virtualHosts = {
        # reverse_proxy ${config.services.home-assistant.config.http.server_host}:${toString config.services.home-assistant.config.http.server_port}
      "raspite.local:1000".extraConfig = ''
        reverse_proxy http://[::1]:8123
      '';

      "raspite.local:1001".extraConfig = ''
        reverse_proxy ${config.services.esphome.address}:${toString config.services.esphome.port}
      '';
    };
  };
}
