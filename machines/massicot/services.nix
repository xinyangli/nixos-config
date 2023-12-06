{ config, pkgs, inputs, ... }:
let
  kanidm_listen_port = 5324;
in
{
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
      oidc-client-secret = "QkqhD6kWj8QLACa51YyFttTfyGMkFyESPsSKzvGVT8WTs3J5";
      oidc-link-existing = true;
    };
  };

  services.forgejo = {
    enable = true;
    settings = {
      service.DISABLE_REGISTRATION = true;
      server = {
        ROOT_URL = "https://git.xinyang.life/";
        START_SSH_SERVER = true;
        BUILTIN_SSH_SERVER_USER = "git";
        SSH_DOMAIN = "ssh.xinyang.life";
        SSH_PORT = 2222;
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

  services.caddy = {
    enable = true;
    virtualHosts."xinyang.life:443".extraConfig = ''
      tls internal
      encode zstd gzip
      reverse_proxy /_matrix/* localhost:6167
      handle_path /.well-known/matrix/client {
          header Content-Type "application/json"
          header Access-Control-Allow-Origin "*"
          header Content-Disposition attachment; filename="client"
          respond `{"m.homeserver":{"base_url":"https://xinyang.life/"}, "org.matrix.msc3575.proxy":{"url":"https://xinyang.life/"}}`
      }
      handle_path /.well-known/matrix/server {
          header Content-Type "application/json"
          header Access-Control-Allow-Origin "*"
          respond `{"m.server": "xinyang.life:443"}`
      }
      reverse_proxy * http://localhost:8080 {
          flush_interval -1
      }
    '';
    virtualHosts."git.xinyang.life:443".extraConfig = ''
      reverse_proxy http://${config.services.gitea.settings.server.DOMAIN}:${toString config.services.gitea.settings.server.HTTP_PORT}
    '';
    
    virtualHosts."http://auth.xinyang.life:80".extraConfig = ''
        reverse_proxy ${config.security.acme.certs."auth.xinyang.life".listenHTTP}
        route {
           reverse_proxy * ${config.security.acme.certs."auth.xinyang.life".listenHTTP} order first
           abort
        }
    '';
    virtualHosts."https://auth.xinyang.life:443".extraConfig = ''
      reverse_proxy https://auth.xinyang.life:${toString kanidm_listen_port} {
          header_up Host {upstream_hostport}
          header_down Access-Control-Allow-Origin "*"
          transport http {
              tls_server_name ${config.services.kanidm.serverSettings.domain}
          }
      }
    '';
    # 
    # respond `Hello World`

  };

  networking.firewall.allowedTCPPorts = [ 80 443 2222 8448 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8448 ];
}
