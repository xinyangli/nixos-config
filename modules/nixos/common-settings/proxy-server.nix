{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    ;

  cfg = config.commonSettings.proxyServer;

  host = "${config.networking.hostName}.video.namely.icu";
  outbound_direct_mark = "0x1451";

  singTls = {
    enabled = true;
    server_name = host;
    # key_path = config.security.acme.certs.${host}.directory + "/key.pem";
    # certificate_path = config.security.acme.certs.${host}.directory + "/cert.pem";
    acme = {
      domain = [ host ];
      disable_http_challenge = cfg.dns01;
      disable_tls_alpn_challenge = true;
      alternative_http_port = if config.services.caddy.enable then 30310 else 80;
      email = "me@namely.icu";
      dns01_challenge = mkIf cfg.dns01 {
        provider = "cloudflare";
        api_token = {
          _secret = config.sops.secrets."sing-box/dns01_apikey".path;
        };
      };
    };
  };

  mkSingConfig = users: {
    log = {
      level = "warn";
    };
    inbounds = [
      {
        tag = "sg0";
        type = "trojan";
        listen = "::";
        listen_port = cfg.trojan.port;
        tcp_multi_path = true;
        tcp_fast_open = true;
        users = map (user: {
          name = user.name;
          password = {
            _secret = user.passwordFile;
          };
        }) users;
        tls = singTls;
      }
    ]
    ++ lib.forEach (lib.range 6311 6314) (port: {
      tag = "sg" + toString (port - 6310);
      type = "tuic";
      listen = "::";
      listen_port = port;
      congestion_control = "bbr";
      users = map (user: {
        name = user.name;
        uuid = {
          _secret = user.uuidFile;
        };
        password = {
          _secret = user.passwordFile;
        };
      }) users;
      tls = singTls;
    });
    outbounds =
      # warp outbound goes first to make it default outbound
      (lib.optionals (cfg.warp.onTuic or cfg.warp.onTrojan) [
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
      ])
      ++ [
        {
          type = "direct";
          tag = "direct";
          routing_mark = outbound_direct_mark;
        }
      ];
    route = {
      rules = [
        {
          inbound = "sg4";
          outbound = "direct";
        }
      ]
      ++ (lib.optionals (!cfg.warp.onTuic) (
        lib.forEach (lib.range 1 3) (i: {
          inbound = "sg${toString i}";
          outbound = "direct";
        })
      ))
      ++ (lib.optionals (!cfg.warp.onTrojan) [
        {
          inbound = "sg0";
          outbound = "direct";
        }
      ]);
    };
    experimental = {
      v2ray_api = {
        listen = "127.0.0.1:15175";
        stats = {
          users = map (u: u.name) users;
          enabled = true;
          inbounds = map (p: "sg" + toString p) (lib.range 0 4);
        };
      };
    };
  };
  sing-box = pkgs.sing-box.overrideAttrs (
    finalAttrs: previousAttrs: {
      tags = previousAttrs.tags ++ [
        "with_v2ray_api"
      ];
    }
  );
in
{
  options.commonSettings.proxyServer = {
    enable = mkEnableOption "sing-box as a server";

    dns01 = mkOption {
      type = lib.types.bool;
      default = false;
    };
    trojan = {
      port = mkOption {
        type = lib.types.port;
        default = 8080;
      };
    };

    warp = {
      onTrojan = mkEnableOption "forward to warp in trojan";
      onTuic = mkEnableOption "forward to warp in first two port of tuic";
    };

    users = mkOption {
      type = lib.types.listOf lib.types.str;
    };
  };

  config = mkIf cfg.enable (
    {
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };

      networking.firewall.trustedInterfaces = [ "tun0" ];

      # For acme
      services.caddy.virtualHosts."http://${host}:80".extraConfig = ''
        reverse_proxy 127.0.0.1:30310
      '';

      networking.firewall.allowedTCPPorts = [ cfg.trojan.port ];
      networking.firewall.allowedUDPPorts = lib.range 6311 6314;

      services.sing-box = {
        enable = true;
        package = sing-box;
        settings = (
          mkSingConfig (
            map (n: {
              name = n;
              uuidFile = config.sops.secrets."sing-box/users/${n}/uuid".path;
              passwordFile = config.sops.secrets."sing-box/users/${n}/password".path;
            }) cfg.users
          )
        );
      };

      networking.nftables.enable = true;
      networking.nftables.ruleset = ''
        table inet filter {
            # Output chain to filter outgoing traffic
            chain output {
                type filter hook output priority filter; policy accept;
                
                # Block IPv4 localhost for packets with mark 0x1
                mark ${outbound_direct_mark} ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 } counter drop
                
                # Block IPv6 localhost for packets with mark 0x1
                mark ${outbound_direct_mark} ip6 daddr { ::1, fe80::/10, fc00::/7 } counter drop
            }
        }
      '';
    }
    // {
      sops.secrets =
        (builtins.foldl' (a: b: a // b) { } (
          map (u: {
            "sing-box/users/${u}/uuid" = { };
            "sing-box/users/${u}/password" = { };
          }) cfg.users
        ))
        // (lib.optionalAttrs cfg.dns01 {
          "sing-box/dns01_apikey" = { };
        });
    }
  );
}
