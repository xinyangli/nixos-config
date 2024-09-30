{ config, pkgs, ... }:
{
  services.ocis = {
    enable = true;
    package = pkgs.ocis;
    stateDir = "/var/lib/ocis";
    url = "https://drive.xinyang.life:8443";
    address = "127.0.0.1";
    port = 9200;
    configDir = "/var/lib/ocis/config";
    environment = {
      OCIS_INSECURE = "false";
      PROXY_TLS = "false";
      OCIS_LOG_LEVEL = "debug";
      OCIS_LOG_PRETTY = "true";
      PROXY_AUTOPROVISION_ACCOUNTS = "true";
      PROXY_USER_OIDC_CLAIM = "preferred_username";
      PROXY_OIDC_ISSUER = "https://auth.xinyang.life/oauth2/openid/owncloud-android";
      PROXY_OIDC_REWRITE_WELLKNOWN = "true";
      PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD = "none";
      OCIS_EXCLUDE_RUN_SERVICES = "idp";
      WEB_HTTP_ADDR = "127.0.0.1:12345";
      WEB_OIDC_METADATA_URL = "https://auth.xinyang.life/oauth2/openid/owncloud-android/.well-known/openid-configuration";
      WEB_OIDC_AUTHORITY = "https://auth.xinyang.life/oauth2/openid/owncloud-android";
      WEB_OIDC_CLIENT_ID = "owncloud-android";
    };
    # environmentFile = config.sops.secrets."ocis/env".path;
  };

  networking.firewall.allowedTCPPorts = [ 8443 ];
  services.caddy.virtualHosts."${config.services.ocis.url}".extraConfig = ''
    reverse_proxy ${config.services.ocis.address}:${toString config.services.ocis.port}
  '';
}
