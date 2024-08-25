{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.custom.hedgedoc;
in
{
  options = {
    custom.hedgedoc = {
      enable = mkEnableOption "HedgeDoc Markdown Editor";
      domain = mkOption {
        type = types.str;
        default = "docs.example.com";
        description = "Domain name of the HedgeDoc server";
      };
      caddy = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Caddy as reverse proxy";
      };
      mediaPath = mkOption {
        type = types.path;
        default = /var/lib/hedgedoc/uploads;
        description = "Directory for storing medias";
      };
      oidc = {
        enable = mkEnableOption "OIDC support for HedgeDoc";
        baseURL = mkOption { type = types.str; };
        authorizationURL = mkOption { type = types.str; };
        tokenURL = mkOption { type = types.str; };
        userProfileURL = mkOption { type = types.str; };
      };
      environmentFile = mkOption { type = types.path; };
    };
  };
  config = mkIf cfg.enable {
    services.hedgedoc = {
      enable = true;
      environmentFile = cfg.environmentFile;
      settings = {
        domain = cfg.domain;
        protocolUseSSL = cfg.caddy;
        uploadsPath = cfg.mediaPath;
        path = "/run/hedgedoc/hedgedoc.sock";
        email = false;
        allowEmailRegister = false;
        oauth2 = mkIf cfg.oidc.enable {
          baseURL = cfg.oidc.baseURL;
          authorizationURL = cfg.oidc.authorizationURL;
          tokenURL = cfg.oidc.tokenURL;
          userProfileURL = cfg.oidc.userProfileURL;
          userProfileEmailAttr = "email";
          userProfileUsernameAttr = "name";
          userProfileDisplayNameAttr = "preferred_name";
          scope = "openid email profile";
          clientID = "$HEDGEDOC_CLIENT_ID";
          clientSecret = "$HEDGEDOC_CLIENT_SECRET";
        };
        allowAnonymous = false;
        defaultPermission = "private";
      };
    };
    services.caddy = mkIf cfg.caddy {
      enable = true;
      virtualHosts."https://${cfg.domain}".extraConfig = ''
        reverse_proxy unix/${config.services.hedgedoc.settings.path}
      '';
    };
    users.users.caddy.extraGroups = mkIf cfg.caddy [ "hedgedoc" ];

  };
}
