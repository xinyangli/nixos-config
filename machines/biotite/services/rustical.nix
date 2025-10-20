{ config, lib, ... }:
let
  inherit (config.my-lib.settings) idpUrl rusticalUrl;
in
{
  services.rustical = {
    enable = true;
    settings = {
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
        allow_sign_up = false;
      };
    };
  };

  services.caddy.virtualHosts.${rusticalUrl}.extraConfig = ''
    reverse_proxy 127.0.0.1:${toString config.services.rustical.settings.http.port}
  '';
}
