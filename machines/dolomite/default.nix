{ config, lib, ... }:
let
  awsHosts = [ "tok-00" ];
  bwgHosts = [ "la-00" ];
in
{
  imports = [
    ../sops.nix
    ./bandwagon.nix
    ./lightsail.nix
  ];

  config = {
    isBandwagon = builtins.elem config.networking.hostName bwgHosts;
    isLightsail = builtins.elem config.networking.hostName awsHosts;
    sops = {
      secrets = {
        wg_private_key = {
          owner = "root";
          sopsFile = ./secrets + "/${config.networking.hostName}.yaml";
        };
        wg_ipv6_local_addr = {
          owner = "root";
          sopsFile = ./secrets + "/${config.networking.hostName}.yaml";
        };
      };
    };
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

    custom.kanidm-client = {
      enable = true;
      uri = "https://auth.xinyang.life/";
      asSSHAuth = {
        enable = true;
        allowedGroups = [ "linux_users" ];
      };
      sudoers = [ "xin@auth.xinyang.life" ];
    };

    services.openssh = {
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = lib.mkForce "no";
        GSSAPIAuthentication = "no";
        KerberosAuthentication = "no";
      };
    };
    services.fail2ban.enable = true;
    programs.mosh.enable = true;

    security.sudo = {
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };

    services.sing-box =
      let
        singTls = {
          enabled = true;
          server_name = config.deployment.targetHost;
          key_path = config.security.acme.certs.${config.deployment.targetHost}.directory + "/key.pem";
          certificate_path =
            config.security.acme.certs.${config.deployment.targetHost}.directory + "/cert.pem";
        };
        password = {
          _secret = config.sops.secrets.singbox_password.path;
        };
        uuid = {
          _secret = config.sops.secrets.singbox_uuid.path;
        };
      in
      {
        enable = true;
        settings = {
          dns = {
            servers = [
              {
                tag = "warp";
                address = "1.1.1.1";
                detour = "wg-out";
              }
              {
                tag = "directdns";
                address = "h3://8.8.8.8/dns-query";
              }
            ];
            rules = [
              {
                outbound = "wg-out";
                server = "warp";
              }
              {
                outbound = "direct";
                server = "directdns";
              }
            ];
          };
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
                    password = password;
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
                  uuid = uuid;
                  password = password;
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
            {
              type = "dns";
              tag = "dns-out";
            }
          ];
          route = {
            rules = [
              {
                outbound = "dns-out";
                protocol = "dns";
              }
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
      };
  };

}
