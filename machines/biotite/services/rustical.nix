{ config, lib, ... }:
let
  inherit (config.my-lib.settings) idpUrl rusticalUrl;
  rusticalListenAddress = "127.0.0.1:4000";
in
{
  sops.secrets."rustical/client_secret" = { };
  sops.templates."rustical.env".content = ''
    RUSTICAL_OIDC__CLIENT_SECRET=${config.sops.placeholder."rustical/client_secret"}
  '';
  services.rustical = {
    enable = true;
    settings = {
      http.bind = rusticalListenAddress;
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
    environmentFiles = [ config.sops.templates."rustical.env".path ];
  };

  services.caddy.virtualHosts.${rusticalUrl}.extraConfig = ''
    reverse_proxy ${rusticalListenAddress}
  '';
}
