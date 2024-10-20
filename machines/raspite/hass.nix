{ config, pkgs, ... }:
{
  services.home-assistant = {
    enable = true;
    openFirewall = false;
    config = {
      default_config = { };
      http = {
        server_host = "127.0.0.1";
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" ];
      };
    };
    extraPackages =
      python3Packages: with python3Packages; [
        # speed up aiohttp
        isal
        zlib-ng
      ];
  };

  services.esphome = {
    enable = true;
    openFirewall = false;
  };

  users.groups.dialout.members = config.users.groups.wheel.members;

  services.mosquitto = {
    enable = true;
  };

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      home-assistant = config.services.home-assistant.enable;
      permit_join = true;
      serial = {
        port = "/dev/ttyUSB0";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8443 ];

  services.caddy = {
    enable = true;
    virtualHosts = {
      "raspite.coho-tet.ts.net".extraConfig = ''
        reverse_proxy ${config.services.home-assistant.config.http.server_host}:${toString config.services.home-assistant.config.http.server_port}
      '';
    };
  };
}
