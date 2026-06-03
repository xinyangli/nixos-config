{
  config,
  pkgs,
  lib,
  ...
}:
let
  kanidm_listen_port = 5324;
  inherit (config.my-lib.settings) idpUrl;
in
{
  imports = [
    ./kanidm-provision.nix
  ];

  security.acme = {
    acceptTerms = true;
    certs.${idpUrl} = {
      email = "lixinyang411@gmail.com";
      listenHTTP = "127.0.0.1:1360";
      group = "kanidm";
    };
  };

  services.kanidm = {
    package = lib.mkForce pkgs.kanidmWithSecretProvisioning_1_10;
    server = {
      enable = true;
      settings = {
        domain = idpUrl;
        origin = "https://${idpUrl}";
        bindaddress = "[::]:${toString kanidm_listen_port}";
        tls_key = ''${config.security.acme.certs.${idpUrl}.directory}/key.pem'';
        tls_chain = ''${config.security.acme.certs.${idpUrl}.directory}/fullchain.pem'';
        online_backup.versions = 7;
        # db_path = "/var/lib/kanidm/kanidm.db";
      };
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts."http://${idpUrl}".extraConfig = ''
      reverse_proxy ${config.security.acme.certs.${idpUrl}.listenHTTP}
    '';
    virtualHosts."https://${idpUrl}".extraConfig = ''
      reverse_proxy https://127.0.0.1:${toString kanidm_listen_port} {
          header_up Host {upstream_hostport}
          header_down Access-Control-Allow-Origin "*"
          transport http {
              tls_server_name ${config.services.kanidm.server.settings.domain}
          }
      }
    '';
  };
}
