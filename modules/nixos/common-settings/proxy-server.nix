{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.commonSettings.proxyServer;

  singTls = {
    enabled = true;
    server_name = config.deployment.targetHost;
    key_path = config.security.acme.certs.${config.deployment.targetHost}.directory + "/key.pem";
    certificate_path =
      config.security.acme.certs.${config.deployment.targetHost}.directory + "/cert.pem";
  };

  mkSingConfig =
    { uuid, password, ... }:
    {
      inbounds =
        [
          {
            tag = "sg0";
            type = "trojan";
            listen = "::";
            listen_port = 8080;
            users = [
              {
                name = "proxy";
                password = {
                  _secret = password;
                };
              }
            ];
            tls = singTls;
          }
        ]
        ++ lib.forEach (lib.range 6311 6314) (port: {
          tag = "sg" + toString (port - 6310);
          type = "tuic";
          listen = "::";
          listen_port = port;
          congestion_control = "bbr";
          users = [
            {
              name = "proxy";
              uuid = {
                _secret = uuid;
              };
              password = {
                _secret = password;
              };
            }
          ];
          tls = singTls;
        });
      outbounds = [
        {
          type = "wireguard";
          tag = "wg-out";
          private_key = {
            _secret = config.sops.secrets.wg_private_key.path;
          };
          local_address = [
            "172.16.0.2/32"
            { _secret = config.sops.secrets.wg_ipv6_local_addr.path; }
          ];
          peers = [
            {
              public_key = "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=";
              allowed_ips = [
                "0.0.0.0/0"
                "::/0"
              ];
              server = "162.159.192.1";
              server_port = 500;
            }
          ];
        }
        {
          type = "direct";
          tag = "direct";
        }
      ];
      route = {
        rules = [
          {
            inbound = "sg0";
            outbound = "direct";
          }
          {
            inbound = "sg4";
            outbound = "direct";
          }
        ];
      };
    };
in
{
  options.commonSettings.proxyServer = {
    enable = mkEnableOption "sing-box as a server";
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    networking.firewall.trustedInterfaces = [ "tun0" ];

    security.acme = {
      acceptTerms = true;
      certs.${config.deployment.targetHost} = {
        email = "me@namely.icu";
        # Avoid port conflict
        listenHTTP = if config.services.caddy.enable then ":30310" else ":80";
      };
    };
    services.caddy.virtualHosts."http://${config.deployment.targetHost}:80".extraConfig = ''
      reverse_proxy 127.0.0.1:30310
    '';

    networking.firewall.allowedTCPPorts = [
      80
      8080
    ];
    networking.firewall.allowedUDPPorts = [ ] ++ (lib.range 6311 6314);

    custom.prometheus = {
      enable = true;
      exporters.blackbox.enable = true;
    };

    services.sing-box = {
      enable = true;
      settings = mkSingConfig {
        uuid = config.sops.secrets."sing-box/uuid".path;
        password = config.sops.secrets."sing-box/password".path;
      };
    };
  };
}
