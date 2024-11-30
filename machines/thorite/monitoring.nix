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
      ruleModules = (mkCaddyRules [ { host = "thorite"; } ]) ++ (mkNodeRules [ { host = "thorite"; } ]);
    };

    services.prometheus.scrapeConfigs =
      let
        probeList = [
          "la-00.video.namely.icu:8080"
          "fre-00.video.namely.icu:8080"
          "hk-00.video.namely.icu:8080"
          "49.13.13.122:443"
          "45.142.178.32:22"
          "home.xinyang.life:8000"
        ];
      in
      (mkScrapes [
        {
          name = "immich";
          scheme = "http";
          address = "weilite.coho-tet.ts.net";
          port = 8082;
        }
        {
          name = "gotosocial";
          address = "xinyang.life";
        }
        {
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
          targetAddresses = probeList;
        }
        {
          hostAddress = "massicot.coho-tet.ts.net";
          targetAddresses = probeList;
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
