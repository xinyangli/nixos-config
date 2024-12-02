{
  config,
  pkgs,
  lib,
  ...
}:
let
  kanidm_listen_port = 5324;
in
{
  imports = [
    ./kanidm-provision.nix
  ];
  networking.firewall.allowedTCPPorts = [
    80
    443
    2222
    8448
  ];
  networking.firewall.allowedUDPPorts = [
    80
    443
    8448
  ];

  custom.vaultwarden = {
    enable = true;
    domain = "vaultwarden.xinyang.life";
  };

  custom.hedgedoc = {
    enable = true;
    caddy = true;
    domain = "docs.xinyang.life";
    mediaPath = "/mnt/storage/hedgedoc";
    oidc = {
      enable = true;
      baseURL = "https://auth.xinyang.life/oauth2/openid/hedgedoc";
      authorizationURL = "https://auth.xinyang.life/ui/oauth2";
      tokenURL = "https://auth.xinyang.life/oauth2/token";
      userProfileURL = "https://auth.xinyang.life/oauth2/openid/hedgedoc/userinfo";
    };
    environmentFile = config.sops.secrets.hedgedoc_env.path;
  };

  custom.monitoring = {
    promtail.enable = true;
  };

  custom.prometheus.exporters = {
    enable = true;
    blackbox = {
      enable = true;
    };
    node = {
      enable = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    certs."auth.xinyang.life" = {
      email = "lixinyang411@gmail.com";
      listenHTTP = "127.0.0.1:1360";
      group = "kanidm";
    };
  };

  services.ntfy-sh = {
    enable = true;
    group = "caddy";
    settings = {
      listen-unix = "/var/run/ntfy-sh/ntfy.sock";
      listen-unix-mode = 432; # octal 0660
      base-url = "https://ntfy.xinyang.life";
    };
  };

  systemd.services.ntfy-sh.serviceConfig.RuntimeDirectory = "ntfy-sh";

  services.kanidm = {
    package = pkgs.kanidm.withSecretProvisioning;
    enableServer = true;
    serverSettings = {
      domain = "auth.xinyang.life";
      origin = "https://auth.xinyang.life";
      bindaddress = "[::]:${toString kanidm_listen_port}";
      tls_key = ''${config.security.acme.certs."auth.xinyang.life".directory}/key.pem'';
      tls_chain = ''${config.security.acme.certs."auth.xinyang.life".directory}/fullchain.pem'';
      online_backup.versions = 7;
      # db_path = "/var/lib/kanidm/kanidm.db";
    };
  };

  custom.miniflux = {
    enable = true;
    environment = {
      LOG_LEVEL = "debug";
      LISTEN_ADDR = "127.0.0.1:58173";
      BASE_URL = "https://rss.xinyang.life/";
      OAUTH2_PROVIDER = "oidc";
      OAUTH2_CLIENT_ID = "miniflux";
      OAUTH2_REDIRECT_URL = "https://rss.xinyang.life/oauth2/oidc/callback";
      OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://auth.xinyang.life/oauth2/openid/miniflux";
      OAUTH2_USER_CREATION = 1;
    };
    oauth2SecretFile = config.sops.secrets."miniflux/oauth2_secret".path;
  };

  services.matrix-conduit = {
    enable = true;
    package = pkgs.matrix-conduit;
    settings.global = {
      server_name = "xinyang.life";
      port = 6167;
      # database_path = "/var/lib/matrix-conduit/";
      max_concurrent_requests = 100;
      log = "info";
      database_backend = "rocksdb";
      allow_registration = false;

      well_known = {
        client = "https://msg.xinyang.life";
        server = "msg.xinyang.life:443";
      };
    };
  };

  users.users.conduit = {
    isSystemUser = true;
    group = "conduit";
  };
  users.groups.conduit = { };

  services.gotosocial = {
    enable = true;
    settings = {
      log-level = "debug";
      host = "xinyang.life";
      letsencrypt-enabled = false;
      bind-address = "localhost";
      instance-expose-public-timeline = true;
      oidc-enabled = true;
      oidc-idp-name = "Kanidm";
      oidc-issuer = "https://auth.xinyang.life/oauth2/openid/gts";
      oidc-client-id = "gts";
      oidc-link-existing = true;
      storage-local-base-path = "/mnt/storage/gotosocial/storage";
    };
    environmentFile = config.sops.secrets.gts_env.path;
  };

  services.forgejo = {
    enable = true;
    # Use cutting edge instead of lts
    package = pkgs.forgejo;
    repositoryRoot = "/mnt/storage/forgejo/repositories";
    lfs = {
      enable = true;
      contentDir = "/mnt/storage/forgejo/lfs";
    };
    settings = {
      service.DISABLE_REGISTRATION = true;
      server = {
        ROOT_URL = "https://git.xinyang.life/";
        START_SSH_SERVER = false;
        SSH_USER = config.services.forgejo.user;
        SSH_DOMAIN = "ssh.xinyang.life";
        SSH_PORT = 22;
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
      other = {
        SHOW_FOOTER_VERSION = false;
      };
    };
  };

  systemd.services.forgejo = {
    serviceConfig = {
      EnvironmentFile = config.sops.secrets."forgejo/env".path;
      ExecStartPost = ''
        ${lib.getExe config.services.forgejo.package} admin auth update-oauth \
            --id 1 \
            --name kanidm \
            --provider openidConnect \
            --key forgejo \
            --secret $CLIENT_SECRET \
            --icon-url https://auth.xinyang.life/pkg/img/favicon.png \
            --group-claim-name forgejo_role --admin-group Admin
      '';
    };
  };

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

  systemd.services.grafana.serviceConfig.EnvironmentFile =
    config.sops.secrets.grafana_oauth_secret.path;

  users.users.git = {
    isSystemUser = true;
    useDefaultShell = true;
    group = "git";
    extraGroups = [ "forgejo" ];
  };
  users.groups.git = { };

  users.users = {
    ${config.services.caddy.user}.extraGroups = [ config.services.ntfy-sh.group ];
  };

  services.caddy = {
    enable = true;
    virtualHosts."xinyang.life:443".extraConfig = ''
      tls internal
      encode zstd gzip
      reverse_proxy /.well-known/matrix/* localhost:6167
      reverse_proxy * http://localhost:8080 {
          flush_interval -1
      }
    '';
    virtualHosts."https://msg.xinyang.life:443".extraConfig = ''
      reverse_proxy /_matrix/* localhost:6167
    '';
    virtualHosts."https://git.xinyang.life:443".extraConfig = ''
      reverse_proxy http://${config.services.gitea.settings.server.DOMAIN}:${toString config.services.gitea.settings.server.HTTP_PORT}
    '';

    virtualHosts."http://auth.xinyang.life:80".extraConfig = ''
      reverse_proxy ${config.security.acme.certs."auth.xinyang.life".listenHTTP}
    '';
    virtualHosts."https://auth.xinyang.life".extraConfig = ''
      reverse_proxy https://127.0.0.1:${toString kanidm_listen_port} {
          header_up Host {upstream_hostport}
          header_down Access-Control-Allow-Origin "*"
          transport http {
              tls_server_name ${config.services.kanidm.serverSettings.domain}
          }
      }
    '';

    virtualHosts."https://rss.xinyang.life".extraConfig = ''
      reverse_proxy ${config.custom.miniflux.environment.LISTEN_ADDR}
    '';

    virtualHosts."https://ntfy.xinyang.life".extraConfig = ''
      reverse_proxy unix/${config.services.ntfy-sh.settings.listen-unix}
      @httpget {
        protocol http
        method GET
        path_regexp ^/([-_a-z0-9]{0,64}$|docs/|static/)
      }
      redir @httpget https://{host}{uri}
    '';

    virtualHosts."https://grafana.xinyang.life".extraConfig =
      let
        grafanaSettings = config.services.grafana.settings.server;
      in
      ''
        reverse_proxy http://${grafanaSettings.http_addr}:${toString grafanaSettings.http_port}
      '';
  };
}
