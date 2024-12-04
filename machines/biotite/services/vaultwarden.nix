{ config, my-lib, ... }:
let
  inherit (my-lib.settings) vaultwardenUrl;
in
{
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    config = {
      DOMAIN = "${vaultwardenUrl}";
      SIGNUPS_ALLOWED = false;

      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;

      ROCKET_LOG = "normal";
    };
  };

  services.caddy = {
    virtualHosts.${vaultwardenUrl}.extraConfig = with config.services.vaultwarden.config; ''
      reverse_proxy ${ROCKET_ADDRESS}:${toString ROCKET_PORT}
    '';
  };
}
