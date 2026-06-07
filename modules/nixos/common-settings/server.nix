{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.commonSettings.serverComponents;
in
{
  options = {
    commonSettings.serverComponents = {
      enable = lib.mkEnableOption "Common components on servers";
    };
  };
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy = {
      enable = true;
    };

    systemd.services.caddy.serviceConfig = {
      RuntimeDirectory = "caddy";
      RuntimeDirectoryMode = "0700";
    };

    custom.prometheus.exporters = {
      enable = true;
      node.enable = true;
    };

    custom.monitoring = {
      fluent-bit.enable = true;
    };
  };
}
