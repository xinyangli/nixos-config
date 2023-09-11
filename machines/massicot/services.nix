{ config, pkgs, inputs, ... }:
{
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
      landing-page-user = "me";
      instance-expose-public-timeline = true;
    };
  };

  services.gitea = {
    enable = true;
    package = pkgs.forgejo;
    settings = {
      service.DISABLE_REGISTRATION = true;
      server = {
        ROOT_URL = "https://git.xinyang.life/";
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
      tls internal
      reverse_proxy http://${config.services.gitea.settings.server.DOMAIN}:${toString config.services.gitea.settings.server.HTTP_PORT}
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 8448 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8448 ];
}
