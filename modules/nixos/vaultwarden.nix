{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.custom.vaultwarden;
in
{
  options = {
    custom.vaultwarden = {
      enable = mkEnableOption "vaultwarden server";
      domain = mkOption {
        type = types.str;
        default = "bitwarden.example.com";
        description = "Domain name of the vaultwarden server";
      };
      caddy = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Caddy as reverse proxy";
      };
      # TODO: mailserver support
    };
  };
  config = mkIf cfg.enable {
    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      config = {
        DOMAIN = "https://${cfg.domain}";
        SIGNUPS_ALLOWED = false;

        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;

        ROCKET_LOG = "critical";
      };
    };
    services.caddy = mkIf cfg.caddy {
      enable = true;
      virtualHosts."https://${cfg.domain}".extraConfig = ''
        reverse_proxy ${config.services.vaultwarden.config.ROCKET_ADDRESS}:${toString config.services.vaultwarden.config.ROCKET_PORT}
      '';
    };
  };
}
