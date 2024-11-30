{ config, lib, ... }:
let
  cfg = config.custom.monitoring.grafana;
in
{
  config = lib.mkIf cfg.enable {
    sops.templates."grafana.env".content = ''
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${config.sops.placeholder."grafana/oauth_secret"}
    '';
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3003;
          root_url = "https://grafana.xinyang.life";
          domain = "grafana.xinyang.life";
        };
        "auth.generic_oauth" = {
          enabled = true;
          name = "Kanidm";
          client_id = "grafana";
          scopes = "openid,profile,email,groups";
          auth_url = "https://auth.xinyang.life/ui/oauth2";
          token_url = "https://auth.xinyang.life/oauth2/token";
          api_url = "https://auth.xinyang.life/oauth2/openid/grafana/userinfo";
          use_pkce = true;
          use_refresh_token = true;
          allow_sign_up = true;
          login_attribute_path = "preferred_username";
          groups_attribute_path = "groups";
          role_attribute_path = "contains(grafana_role[*], 'GrafanaAdmin') && 'GrafanaAdmin' || contains(grafana_role[*], 'Admin') && 'Admin' || contains(grafana_role[*], 'Editor') && 'Editor' || 'Viewer'";
          allow_assign_grafana_admin = true;
          auto_login = true;
        };
        "auth" = {
          disable_login_form = true;
        };
      };
    };
    systemd.services.grafana.serviceConfig.EnvironmentFile = config.sops.templates."grafana.env".path;
  };
}
