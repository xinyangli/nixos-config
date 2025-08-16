{ config, pkgs, ... }:
let
  inherit (config.my-lib.settings) idpUrl ocisUrl;
in
{
  sops.secrets = {
    "ocis/s3_access_key" = { };
    "ocis/s3_secret_key" = { };
  };
  sops.templates."ocis/env".content = ''
    STORAGE_USERS_S3NG_ACCESS_KEY=${config.sops.placeholder."ocis/s3_access_key"}
    STORAGE_USERS_S3NG_SECRET_KEY=${config.sops.placeholder."ocis/s3_secret_key"}
  '';
  services.ocis = {
    enable = true;
    package = pkgs.ocis;
    stateDir = "/var/lib/ocis";
    url = ocisUrl;
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
      PROXY_OIDC_ISSUER = "https://${idpUrl}/oauth2/openid/owncloud-android";
      PROXY_OIDC_REWRITE_WELLKNOWN = "true";
      PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD = "none";
      OCIS_EXCLUDE_RUN_SERVICES = "idp";
      WEB_HTTP_ADDR = "127.0.0.1:12345";
      WEB_OIDC_METADATA_URL = "https://${idpUrl}/oauth2/openid/owncloud-android/.well-known/openid-configuration";
      WEB_OIDC_AUTHORITY = "https://${idpUrl}/oauth2/openid/owncloud-android";
      WEB_OIDC_CLIENT_ID = "owncloud-android";

      AUTH_SERVICE_DEBUG_ADDR = "127.0.0.1:19198";

      STORAGE_USERS_DRIVER = "s3ng";
      STORAGE_USERS_S3NG_ROOT = "/var/lib/ocis/users";
      STORAGE_USERS_S3NG_ENDPOINT = "http://127.0.0.1:3901";
      STORAGE_USERS_S3NG_BUCKET = "owncloud-bucket";
    };
    environmentFile = config.sops.templates."ocis/env".path;
  };

  # systemd.services.ocis.serviceConfig = {
  #   BindPaths = [
  #     "/storage/ocis/storage:%S/ocis/storage" # /var/lib/ocis/storage
  #   ];
  # };

  services.caddy.virtualHosts.${ocisUrl}.extraConfig = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
    }
    reverse_proxy ${config.services.ocis.address}:${toString config.services.ocis.port}
  '';
}
