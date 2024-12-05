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

  services.caddy = {
    enable = true;
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
  };
}
