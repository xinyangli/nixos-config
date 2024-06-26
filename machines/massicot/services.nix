{ config, pkgs, inputs, ... }:
let
  kanidm_listen_port = 5324;
in
{
  networking.firewall.allowedTCPPorts = [ 80 443 2222 8448 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8448 ];

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

  custom.prometheus = {
    enable = true;
    exporters.enable = true;
    grafana = {
      enable = true;
      password_file = config.sops.secrets.grafana_cloud_api.path;
    };
  };

  systemd.mounts = map (share: {
    what = "//u380335-sub1.your-storagebox.de/u380335-sub1/${share}";
    where = "/mnt/storage/${share}";
    type = "cifs";
    options = "rw,uid=${share},gid=${share},credentials=${config.sops.secrets.storage_box_mount.path},_netdev,fsc";
    before = [ "${share}.service" ];
    after = [ "cachefilesd.service" ];
    wantedBy = [ "${share}.service" ];
  }) [ "forgejo" "gotosocial" "conduit" "hedgedoc" ];

  services.cachefilesd.enable = true;

  system.activationScripts = {
    conduit-media-link.text = ''
      mkdir -m 700 -p /var/lib/private/matrix-conduit/media
      chown conduit:conduit /var/lib/private/matrix-conduit/media
      mount --bind --verbose /mnt/storage/conduit/media /var/lib/private/matrix-conduit/media
    '';
  };
  security.acme = {
    acceptTerms = true;
    certs."auth.xinyang.life" = {
        email = "lixinyang411@gmail.com";
        listenHTTP = "127.0.0.1:1360";
        group = "kanidm";
    };
  };
  services.kanidm = {
    enableServer = true;
    serverSettings = {
      domain = "auth.xinyang.life";
      origin = "https://auth.xinyang.life";
      bindaddress = "[::]:${toString kanidm_listen_port}";
      tls_key = ''${config.security.acme.certs."auth.xinyang.life".directory}/key.pem'';
      tls_chain = ''${config.security.acme.certs."auth.xinyang.life".directory}/fullchain.pem'';
      # db_path = "/var/lib/kanidm/kanidm.db";
    };
  };
  services.matrix-conduit = {
    enable = true;
    # package = inputs.conduit.packages.${pkgs.system}.default;
    package = pkgs.matrix-conduit;
    settings.global = {
      server_name = "xinyang.life";
      port = 6167;
      # database_path = "/var/lib/matrix-conduit/";
      max_concurrent_requests = 100;
      log = "info";
      database_backend = "rocksdb";
      allow_registration = false;
    };
  };

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
    repositoryRoot = "/mnt/storage/forgejo/repositories";
    lfs = {
      enable = true;
      contentDir = "/mnt/storage/forgejo/lfs";
    };
    settings = {
      service.DISABLE_REGISTRATION = true;
      server = {
        ROOT_URL = "https://git.xinyang.life/";
        START_SSH_SERVER = true;
        BUILTIN_SSH_SERVER_USER = "git";
        SSH_USER = "git";
        SSH_DOMAIN = "ssh.xinyang.life";
        SSH_PORT = 2222;
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
        ENABLE = false; # Disable forgejo as oauth2 provider
      };
      oauth2_client = {
        ACCOUNT_LINKING = "auto";
        ENABLE_AUTO_REGISTRATION = true;
        UPDATE_AVATAR = true;
        OPENID_CONNECT_SCOPES = "openid profile email";
      };
      other = {
        SHOW_FOOTER_VERSION = false;
      };
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
    enable = true;
    virtualHosts."xinyang.life:443".extraConfig = ''
      tls internal
      encode zstd gzip
      handle_path /.well-known/matrix/client {
          header Content-Type "application/json"
          header Access-Control-Allow-Origin "*"
          header Content-Disposition attachment; filename="client"
          respond `{"m.homeserver":{"base_url":"https://msg.xinyang.life/"}, "org.matrix.msc3575.proxy":{"url":"https://msg.xinyang.life/"}}`
      }
      handle_path /.well-known/matrix/server {
          header Content-Type "application/json"
          header Access-Control-Allow-Origin "*"
          respond `{"m.server": "msg.xinyang.life:443"}`
      }
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
        route {
           reverse_proxy * ${config.security.acme.certs."auth.xinyang.life".listenHTTP} order first
           abort
        }
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
  };
}
