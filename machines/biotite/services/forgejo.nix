{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
  inherit (config.my-lib.settings) idpUrl forgejoDomain forgejoGitDomain;
  settings = {
    service.DISABLE_REGISTRATION = true;
    server = {
      DOMAIN = forgejoDomain;
      ROOT_URL = "https://${forgejoDomain}";
      HTTP_ADDR = "/var/run/forgejo/forgejo.sock";
      START_SSH_SERVER = false;
      SSH_USER = config.services.forgejo.user;
      SSH_DOMAIN = forgejoGitDomain;
      SSH_PORT = 22;
      PROTOCOL = "http+unix";
      LFS_MAX_FILE_SIZE = 10737418240;
      LANDING_PAGE = "/explore/repos";
    };
    repository = {
      ENABLE_PUSH_CREATE_USER = true;
    };
    service = {
      ENABLE_BASIC_AUTHENTICATION = false;
    };
    oauth2 = {
      ENABLED = false; # Disable forgejo as oauth2 provider
    };
    oauth2_client = {
      ACCOUNT_LINKING = "auto";
      USERNAME = "email";
      ENABLE_AUTO_REGISTRATION = true;
      UPDATE_AVATAR = false;
      OPENID_CONNECT_SCOPES = "openid profile email groups";
    };
    metrics = {
      ENABLED = true;
    };
    other = {
      SHOW_FOOTER_VERSION = false;
    };
  };
in
{
  sops.secrets."forgejo/client_secret" = { };
  sops.templates."forgejo/env" = {
    content = ''
      CLIENT_SECRET=${config.sops.placeholder."forgejo/client_secret"}
    '';
    owner = config.systemd.services.forgejo.serviceConfig.User;
  };

  services.forgejo = {
    enable = true;
    inherit settings;
    # Use cutting edge instead of lts
    package = pkgs.forgejo;
    # repositoryRoot = "/mnt/storage/forgejo/repositories";
    lfs = {
      enable = true;
      # contentDir = "/mnt/storage/forgejo/lfs";
    };
  };

  systemd.services.forgejo = {
    serviceConfig = {
      EnvironmentFile = config.sops.templates."forgejo/env".path;
      preStart =
        let
          providerName = "kanidm";
          args = lib.concatStringsSep " " [
            "--name ${providerName}"
            "--provider openidConnect"
            "--key forgejo"
            "--secret $CLIENT_SECRET"
            "--icon-url ${idpUrl}/pkg/img/favicon.png"
            "--group-claim-name forgejo_role --admin-group Admin"
          ];
          exe = getExe config.services.forgejo.package;
        in
        ''
          provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
          if [[ -z "$provider_id" ]]; then
            ${exe} admin auth add-oauth ${args}
          else
            ${exe} admin auth update-oauth --id "$provider_id" ${args}
          fi
        '';
    };
  };

  users.users.git = {
    isSystemUser = true;
    useDefaultShell = true;
    group = "git";
    extraGroups = [ "forgejo" ];
  };
  users.groups.git = { };

  services.caddy = {
    virtualHosts."https://${forgejoDomain}".extraConfig = with settings; ''
      ${
        if server.PROTOCOL == "http+unix" then
          "reverse_proxy unix/${server.HTTP_ADDR}"
        else
          "reverse_proxy http://${server.HTTP_ADDR}:${toString server.HTTP_PORT}"
      }
    '';
  };
  users.users.caddy.extraGroups = lib.optional (settings.server.PROTOCOL == "http+unix") "forgejo";
}
