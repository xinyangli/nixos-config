{ config, my-lib, ... }:
let
  inherit (my-lib.settings) hedgedocDomain idpUrl;
in
{
  sops.secrets."hedgedoc/client_secret" = { };
  sops.templates."hedgedoc/env" = {
    content = ''
      CMD_OAUTH2_CLIENT_SECRET=${config.sops.placeholder."hedgedoc/client_secret"}
    '';
    owner = config.systemd.services.hedgedoc.serviceConfig.User;
  };
  services.hedgedoc = {
    enable = true;
    environmentFile = config.sops.templates."hedgedoc/env".path;
    settings = {
      domain = hedgedocDomain;
      protocolUseSSL = true; # use SSL for resources
      path = "/run/hedgedoc/hedgedoc.sock";
      email = false;
      allowEmailRegister = false;
      oauth2 = {
        baseURL = "${idpUrl}/oauth2/openid/hedgedoc";
        authorizationURL = "${idpUrl}/ui/oauth2";
        tokenURL = "${idpUrl}/oauth2/token";
        userProfileURL = "${idpUrl}/oauth2/openid/hedgedoc/userinfo";
        userProfileEmailAttr = "email";
        userProfileUsernameAttr = "name";
        userProfileDisplayNameAttr = "preferred_name";
        scope = "openid email profile";
        clientID = "hedgedoc";
      };
      allowAnonymous = false;
      defaultPermission = "private";
    };
  };
  services.caddy = {
    enable = true;
    virtualHosts."https://${hedgedocDomain}".extraConfig = ''
      reverse_proxy unix/${config.services.hedgedoc.settings.path}
    '';
  };
  users.users.caddy.extraGroups = [ "hedgedoc" ];
}
