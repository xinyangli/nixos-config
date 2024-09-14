{ config, pkgs, ... }:
{
  sops = {
    secrets = {
      "ocis/env" = {
        sopsFile = ../secrets.yaml;
      };
    };
  };

  services.ocis = {
    enable = true;
    package = pkgs.ocis-bin;
    stateDir = "/var/lib/ocis";
    url = "https://drive.xinyang.life:8443";
    address = "127.0.0.1";
    port = 9200;
    environment = {
      OCIS_INSECURE = "false";
      OCIS_LOG_LEVEL = "trace";
      OCIS_LOG_PRETTY = "true";
      # For reverse proxy. Disable tls.
      OCIS_PROXY_TLS = "false";
      WEB_OIDC_CLIENT_ID = "owncloud";
      WEB_OIDC_ISSUER = "https://auth.xinyang.life/oauth2/openid/owncloud";
      OCIS_EXCLUDE_RUN_SERVICES = "idp";
      PROXY_OIDC_REWRITE_WELLKNOWN = "true";
    };
  };

  networking.allowedTCPPorts = [ 8443 ];

  services.caddy.virtualHosts."${config.services.ocis.url}".extraConfig = ''
    reverse_proxy ${config.services.ocis.address}:${config.services.ocis.address}
  '';
}
