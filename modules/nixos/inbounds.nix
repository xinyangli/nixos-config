{ config, lib, ... }:
let
  cfg = config.custom.sing-box-server;

  secretFileType = lib.types.submodule { _secret = lib.types.path; };
  singTls = {
    enabled = true;
    server_name = config.deployment.targetHost;
    key_path = config.security.acme.certs.${config.deployment.targetHost}.directory + "/key.pem";
    certificate_path =
      config.security.acme.certs.${config.deployment.targetHost}.directory + "/cert.pem";
  };
in
{
  options = {
    enable = lib.mkEnableOption "sing-box proxy server";
    users = lib.types.listOf lib.types.submodule {
      name = lib.mkOption {
        type = lib.types.str;
        default = "proxy";
      };
      password = lib.mkOption { type = secretFileType; };
      uuid = lib.mkOption { type = secretFileType; };
    };
    wgOut = {
      privKeyFile = lib.mkOption { type = lib.types.path; };
      pubkey = lib.mkOption {
        type = lib.types.str;
        default = "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=";
      };
    };
    inbounds = {
      trojan = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };
      tuic = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        ports = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = lib.range 6311 6313;
        };
        directPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ 6314 ];
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services.sing-box = {
      enable = true;
      settings = {
        dns = {
          servers = [
            {
              address = "1.1.1.1";
              detour = "wg-out";
            }
          ];
        };
        inbounds =
          [
            # TODO: Trojan and tuic enable
            {
              tag = "trojan-in";
              type = "trojan";
              listen = "::";
              listen_port = 8080;
              users = map (u: removeAttrs u [ "uuid" ]) cfg.users;
              tls = singTls;
            }
          ]
          ++ lib.forEach (cfg.tuic.ports ++ cfg.tuic.directPorts) (port: {
            tag = "tuic-in" + toString port;
            type = "tuic";
            listen = "::";
            listen_port = port;
            congestion_control = "bbr";
            users = cfg.users;
            tls = singTls;
          });
        outbounds = [
          {
            type = "wireguard";
            tag = "wg-out";
            private_key = cfg.wgOut.privKeyFile;
            local_address = [
              "172.16.0.2/32"
              "2606:4700:110:82ed:a443:3c62:6cbc:b59b/128"
            ];
            peers = [
              {
                public_key = cfg.wgOut.pubkey;
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
            tag = "direct-out";
          }
          {
            type = "dns";
            tag = "dns-out";
          }
        ];
        route = {
          rules =
            [
              {
                outbound = "dns-out";
                protocol = "dns";
              }
            ]
            ++ lib.forEach cfg.tuic.directPorts (port: {
              inbound = "tuic-in" + toString port;
              outbound = "direct-out";
            });
        };
      };
    };
  };
}
