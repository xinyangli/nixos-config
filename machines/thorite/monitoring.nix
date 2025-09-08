{
  config,
  lib,
  pkgs,
  ...
}:
with config.my-lib;
let
  inherit (config.my-lib.settings)
    minifluxUrl
    gotosocialUrl
    hedgedocDomain
    grafanaUrl
    ntfyUrl
    internalDomain
    ;
  removeHttps = s: lib.removePrefix "https://" s;
in
{
  config = {
    sops = {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = {
        "grafana/oauth_secret" = {
          owner = "grafana";
        };
      };
    };

    custom.monitoring = {
      grafana.enable = true;
      loki = {
        enable = true;
        rules = {
          sshd_closed = {
            expr = ''count_over_time({unit="sshd.service"} |~ "Connection closed by authenticating user" [15m]) > 25'';
            description = "More then 25 login attemps in last 15 min without success";
          };
          unusual_log_volume = {
            expr = ''sum by (unit) (rate({unit=~".+"}[5m])) > 80'';
            description = "Unit {{ $labels.unit }} is logging at an unusually high rate";
          };
        };
      };
      promtail.enable = true;
    };

    services.caddy.virtualHosts.${grafanaUrl}.extraConfig =
      with config.services.grafana.settings.server; ''
        reverse_proxy http://${http_addr}:${toString http_port}
      '';

    custom.prometheus = {
      enable = true;
      exporters = {
        enable = true;
        blackbox.enable = true;
        node.enable = true;
      };
      ruleModules = [
        {
          name = "comin_rules";
          rules = [
            {
              alert = "CominBuildFailed";
              expr = "comin_build_info != 1";
              for = "1m";
              labels = {
                severity = "critical";
              };
            }
          ];
        }
      ]
      ++ (mkCaddyRules [ { host = "thorite"; } ])
      ++ (mkNodeRules [ { host = "thorite"; } ])
      ++ (mkBlackboxRules [ { host = "thorite"; } ]);
    };

    services.prometheus.scrapeConfigs =
      let
        probeList = [
          "la-00.video.namely.icu:8080"
          "agate_home.xiny.li:8443"
          "fra-00.video.namely.icu:8080"
        ];
        chinaTargets = [
          "bj-cu-v4.ip.zstaticcdn.com:80"
          "bj-cm-v4.ip.zstaticcdn.com:80"
          "bj-ct-v4.ip.zstaticcdn.com:80"
          "sh-cu-v4.ip.zstaticcdn.com:80"
          "sh-cm-v4.ip.zstaticcdn.com:80"
          "sh-ct-v4.ip.zstaticcdn.com:80"
        ];
        passwordFile = config.sops.secrets."prometheus/metrics_password".path;
      in
      [
        {
          job_name = "comin";
          scheme = "http";
          static_configs = [
            {
              targets = map (host: "${host}.${internalDomain}:4243") [
                "weilite"
                "thorite"
                "la-00"
                "fra-00"
              ];
            }
          ];
        }
      ]
      ++ (mkScrapes [
        {
          name = "immich";
          scheme = "http";
          address = "agate.coho-tet.ts.net";
          port = 8082;
        }
        # {
        #   name = "restic_rest_server";
        #   address = "backup.xinyang.life";
        #   port = 8443;
        # }
        {
          inherit passwordFile;
          name = "gotosocial";
          address = removeHttps gotosocialUrl;
        }
        {
          inherit passwordFile;
          name = "miniflux";
          address = removeHttps minifluxUrl;
        }
        {
          name = "hedgedoc";
          address = hedgedocDomain;
        }
        {
          name = "ntfy";
          address = removeHttps ntfyUrl;
        }
        {
          name = "grafana-eu";
          address = removeHttps grafanaUrl;
        }
        {
          name = "loki";
          scheme = "http";
          address = "thorite.${internalDomain}";
          port = 3100;
        }
        {
          name = "transmission";
          scheme = "http";
          address = "agate.${internalDomain}";
          port = 19091;
        }
        {
          name = "sonarr";
          scheme = "http";
          address = "agate.${internalDomain}";
          port = 21560;
        }
        {
          name = "radarr";
          scheme = "http";
          address = "agate.${internalDomain}";
          port = 21561;
        }
      ])
      ++ (mkCaddyScrapes [
        { address = "thorite.coho-tet.ts.net"; }
        { address = "biotite.coho-tet.ts.net"; }
        { address = "agate.coho-tet.ts.net"; }
        { address = "weilite.coho-tet.ts.net"; }
      ])
      ++ (mkNodeScrapes [
        { address = "thorite.coho-tet.ts.net"; }
        { address = "agate.coho-tet.ts.net"; }
        { address = "weilite.coho-tet.ts.net"; }
        { address = "biotite.coho-tet.ts.net"; }
        { address = "la-00.coho-tet.ts.net"; }
        { address = "fra-00.coho-tet.ts.net"; }
      ])
      ++ (mkBlackboxScrapes [
        {
          hostAddress = "thorite.coho-tet.ts.net";
          targetAddresses = probeList;
        }
        {
          hostAddress = "agate.coho-tet.ts.net";
          targetAddresses = [
            "la-00.video.namely.icu:8080"
            "fra-00.video.namely.icu:8080"
          ];
        }
        {
          hostAddress = "weilite.coho-tet.ts.net";
          targetAddresses = [
            "la-00.video.namely.icu:8080"
            "fra-00.video.namely.icu:8080"
          ];
        }
        {
          hostAddress = "la-00.coho-tet.ts.net";
          targetAddresses = chinaTargets;
        }
        {
          hostAddress = "fra-00.coho-tet.ts.net";
          targetAddresses = chinaTargets;
        }
      ])
      ++ (mkV2rayScrapes [
        { address = "la-00.coho-tet.ts.net"; }
        { address = "fra-00.coho-tet.ts.net"; }
      ]);

  };
}
