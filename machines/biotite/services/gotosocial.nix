{ config, ... }:
{
  sops.secrets."gotosocial/oidc_client_secret" = {
    owner = "gotosocial";
  };

  sops.templates."gotosocial.env" = {
    owner = "gotosocial";
    content = ''
      GTS_OIDC_CLIENT_SECRET=${config.sops.placeholder."gotosocial/oidc_client_secret"}
    '';
  };

  services.gotosocial = {
    enable = true;
    settings = {
      log-level = "info";
      bind-address = "127.0.0.1";
      port = 19571;
      host = "gts.xiny.li";
      account-domain = "xiny.li";
      letsencrypt-enabled = false;
      instance-expose-public-timeline = true;
      oidc-enabled = true;
      oidc-idp-name = "Kanidm";
      oidc-issuer = "https://auth.xinyang.life/oauth2/openid/gotosocial";
      oidc-client-id = "gotosocial";
      oidc-link-existing = true;
    };
    environmentFile = config.sops.templates."gotosocial.env".path;
  };

  services.caddy = {
    virtualHosts."https://gts.xiny.li".extraConfig = ''
      reverse_proxy http://${config.services.gotosocial.settings.bind-address}:${toString config.services.gotosocial.settings.port} {
          flush_interval -1
      }
    '';
    virtualHosts."https://xiny.li".extraConfig = ''
      redir /.well-known/host-meta* https://gts.xiny.li{uri} permanent  # host
      redir /.well-known/webfinger* https://gts.xiny.li{uri} permanent  # host
      redir /.well-known/nodeinfo* https://gts.xiny.li{uri} permanent   # host
    '';
  };
}
