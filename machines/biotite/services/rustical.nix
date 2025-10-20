{ config, lib, ... }:
let
  inherit (config.my-lib.settings) idpUrl rusticalUrl;
in
{
  sops.secrets."rustical/client_secret" = { };
  sops.templates."rustical.env".content = ''
    RUSTICAL_OIDC__CLIENT_SECRET=${config.sops.placeholder."rustical/client_secret"}
  '';
  services.rustical = {
    enable = true;
    settings = {
      http.host = "127.0.0.1";
      oidc = {
        name = "Kanidm";
        issuer = "https://${idpUrl}/oauth2/openid/rustical";
        client_id = "rustical";
        claim_userid = "preferred_username";
        scopes = [
          "openid"
          "profile"
          "groups"
        ];
        allow_sign_up = true;
      };
      frontend.allow_password_login = false;
    };
    environmentFile = config.sops.templates."rustical.env".path;
  };

  services.caddy.virtualHosts.${rusticalUrl}.extraConfig = ''
    reverse_proxy 127.0.0.1:${toString config.services.rustical.settings.http.port}
  '';
}
