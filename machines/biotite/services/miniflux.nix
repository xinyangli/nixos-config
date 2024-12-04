{ config, my-lib, ... }:
let
  inherit (my-lib.settings) idpUrl minifluxUrl;
in
{
  sops = {
    secrets."miniflux/oauth2_secret" = { };
  };

  services.miniflux = {
    enable = true;
    config = {
      LOG_LEVEL = "debug";
      LISTEN_ADDR = "127.0.0.1:58173";
      BASE_URL = "https://rss.xiny.li/";
      OAUTH2_PROVIDER = "oidc";
      OAUTH2_CLIENT_ID = "miniflux";
      OAUTH2_CLIENT_SECRET_FILE = "%d/oauth2_secret";
      OAUTH2_REDIRECT_URL = "${minifluxUrl}/oauth2/oidc/callback";
      OAUTH2_OIDC_DISCOVERY_ENDPOINT = "${idpUrl}/oauth2/openid/miniflux";
      OAUTH2_USER_CREATION = 1;
      CREATE_ADMIN = 0;
    };
    createDatabaseLocally = true;
  };

  systemd.services.miniflux.serviceConfig.LoadCredential = [
    "oauth2_secret:${config.sops.secrets."miniflux/oauth2_secret".path}"
  ];

  services.caddy.virtualHosts.${minifluxUrl}.extraConfig = ''
    reverse_proxy ${config.services.miniflux.config.LISTEN_ADDR}
  '';

}
