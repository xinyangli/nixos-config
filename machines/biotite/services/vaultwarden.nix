{ config, pkgs, ... }:
let
  inherit (config.my-lib.settings) vaultwardenUrl;
in
{

  sops.secrets."vaultwarden/admin_token" = {
    owner = "vaultwarden";
  };

  sops.templates."vaultwarden.env" = {
    owner = "vaultwarden";
    content = ''
      ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin_token"}
    '';
  };

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
    environmentFile = config.sops.templates."vaultwarden.env".path;
  };

  services.caddy = {
    virtualHosts.${vaultwardenUrl}.extraConfig = with config.services.vaultwarden.config; ''
      reverse_proxy ${ROCKET_ADDRESS}:${toString ROCKET_PORT}
    '';
  };
}
