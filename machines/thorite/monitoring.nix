{ config, my-lib, ... }:
with my-lib;
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

    services.caddy.virtualHosts."https://grafana.xinyang.life".extraConfig =
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
      ruleModules =
        (mkCaddyRules [ { host = "thorite"; } ])
        ++ (mkNodeRules [ { host = "thorite"; } ])
        ++ (mkBlackboxRules [ { host = "thorite"; } ]);
    };

    services.prometheus.scrapeConfigs =
      let
        probeList = [
          "la-00.video.namely.icu:8080"
          "fre-00.video.namely.icu:8080"
          "hk-00.video.namely.icu:8080"
          "home.xinyang.life:8000"
        ];
        passwordFile = config.sops.secrets."prometheus/metrics_password".path;
      in
      (mkScrapes [
        {
          name = "immich";
          scheme = "http";
          address = "weilite.coho-tet.ts.net";
          port = 8082;
        }
        {
          name = "restic_rest_server";
          address = "backup.xinyang.life";
          port = 8443;
        }
        {
          inherit passwordFile;
          name = "gotosocial";
          address = "xinyang.life";
        }
        {
          inherit passwordFile;
          name = "miniflux";
          address = "rss.xinyang.life";
        }
        {
          name = "ntfy";
          address = "ntfy.xinyang.life";
        }
        {
          name = "grafana-eu";
          address = "grafana.xinyang.life";
        }
        {
          name = "loki";
          scheme = "http";
          address = "thorite.coho-tet.ts.net";
          port = 3100;
        }
      ])
      ++ (mkCaddyScrapes [
        { address = "thorite.coho-tet.ts.net"; }
      ])
      ++ (mkNodeScrapes [
        { address = "thorite.coho-tet.ts.net"; }
        { address = "massicot.coho-tet.ts.net"; }
        { address = "weilite.coho-tet.ts.net"; }
        { address = "hk-00.coho-tet.ts.net"; }
        { address = "la-00.coho-tet.ts.net"; }
        { address = "fra-00.coho-tet.ts.net"; }
      ])
      ++ (mkBlackboxScrapes [
        {
          hostAddress = "thorite.coho-tet.ts.net";
          targetAddresses = probeList ++ [ "49.13.13.122:22" ];
        }
        {
          hostAddress = "massicot.coho-tet.ts.net";
          targetAddresses = probeList ++ [ "45.142.178.32:22" ];
        }
        {
          hostAddress = "weilite.coho-tet.ts.net";
          targetAddresses = [
            "la-00.video.namely.icu:8080"
            "fre-00.video.namely.icu:8080"
            "hk-00.video.namely.icu:8080"
          ];
        }
      ]);

  };
}
