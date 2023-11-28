{ config, pkgs, lib, modulesPath, ... }:
let
  sg_server = {
    _secret = config.sops.secrets.singbox_sg_server.path;
  };
  sg_password = {
    _secret = config.sops.secrets.singbox_sg_password.path;
  };
  sg_uuid = {
    _secret = config.sops.secrets.singbox_sg_uuid.path;
  };
  singTls = {
    enabled = true;
    server_name = sg_server;
    key_path = config.security.acme.certs."video.namely.icu".directory + "/key.pem";
    certificate_path = config.security.acme.certs."video.namely.icu".directory + "/cert.pem";
  };
in
{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    ../sops.nix
  ];

  boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  networking.firewall.trustedInterfaces = [ "tun0" ];

  security.acme = {
    acceptTerms = true;
    certs."video.namely.icu" = {
      email = "me@namely.icu";
      listenHTTP = ":80";
    };
  };
  networking.firewall.allowedTCPPorts = [ 80 8080 ];
  networking.firewall.allowedUDPPorts = [ 6311 ];

  services.sing-box = {
    enable = true;
    settings = {
      inbounds = [
        {
          tag = "sg1";
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
        {
          tag = "sg2";
          type = "tuic";
          listen = "::";
          listen_port = 6311;
          congestion_control = "bbr";
          users = [
            { name = "proxy";
              uuid = sg_uuid;
              password = sg_password;
            }
          ];
          tls = singTls;
        }
      ];
    };
  };
}
