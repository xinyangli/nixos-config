{ config, pkgs, lib, modulesPath, ... }:
let
  cfg = config.custom;
  sg_password = {
    _secret = config.sops.secrets.singbox_sg_password.path;
  };
  sg_uuid = {
    _secret = config.sops.secrets.singbox_sg_uuid.path;
  };
  singTls = {
    enabled = true;
    server_name = cfg.domain;
    key_path = config.security.acme.certs.${cfg.domain}.directory + "/key.pem";
    certificate_path = config.security.acme.certs.${cfg.domain}.directory + "/cert.pem";
  };
in
{
  options = {
    custom.domain = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };

  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    ../sops.nix
  ];

  config = {
    boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    networking.firewall.trustedInterfaces = [ "tun0" ];

    security.acme = {
      acceptTerms = true;
      certs.${cfg.domain} = {
        email = "me@namely.icu";
        listenHTTP = ":80";
      };
    };
    networking.firewall.allowedTCPPorts = [ 80 8080 ];
    networking.firewall.allowedUDPPorts = [ ] ++ (lib.range 6311 6314);

    services.sing-box = {
      enable = true;
      settings = {
        inbounds = [
          {
            tag = "sg0";
            type = "trojan";
            listen = "::";
            listen_port = 8080;
            users = [
              { name = "proxy";
                password = sg_password;
              }
            ];
            tls = singTls;
          }
        ] ++ lib.forEach (lib.range 6311 6314) (port: {
            tag = "sg" + toString (port - 6310);
            type = "tuic";
            listen = "::";
            listen_port = port;
            congestion_control = "bbr";
            users = [
              { name = "proxy";
                uuid = sg_uuid;
                password = sg_password;
              }
            ];
            tls = singTls;
          });
      };
    };
  };

}
