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
      fluent-bit.enable = true;
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
              alert = "CominDeployFailed";
              expr = "deployment_up_to_date != 1";
              for = "3h";
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
          "la-00.video.10118244.xyz:8080"
          "agate_home.xiny.li:8443"
          "fra-00.video.10118244.xyz:8080"
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
          job_name = "comin-deployment";
          scheme = "http";
          static_configs = [
            {
              targets = [
                "127.0.0.1:13131"
              ];
            }
          ];
        }
        {
          job_name = "comin";
          scheme = "http";
          static_configs = [
            {
              targets = map (host: "${host}.${internalDomain}:4243") [
                "weilite"
                "thorite"
                "biotite"
                "la-00"
                "fra-00"
                "agate"
                "raspite"
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
            "la-00.video.10118244.xyz:8080"
            "fra-00.video.10118244.xyz:8080"
          ];
        }
        {
          hostAddress = "weilite.coho-tet.ts.net";
          targetAddresses = [
            "la-00.video.10118244.xyz:8080"
            "fra-00.video.10118244.xyz:8080"
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

    systemd.timers.comin-deployment-exporter = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };

    systemd.services.comin-deployment-exporter =
      let
        check_comin_deployment = pkgs.writeShellScript "comin-deployment-export" ''
          set -euo pipefail
          PROMETHEUS_URL="https://thorite.coho-tet.ts.net"
          REPO="xinyangli/nixos-config"
          JOB_NAME="deployment_check"
          CURL=${lib.getExe pkgs.curl}
          JQ=${lib.getExe pkgs.jq}
          get_latest_commit() {
            local branch=$1
            local response
            response=$($CURL -s -f "https://api.github.com/repos/''${REPO}/commits/''${branch}" || true)
            local sha
            sha=$(echo "$response" | $JQ -r '.sha // empty')
            echo "$sha"
          }
          get_commit_time() {
            local sha=$1
            if [[ -z "$sha" || "$sha" == "null" ]]; then
              echo ""
              return
            fi
            $CURL -s "https://api.github.com/repos/''${REPO}/commits/''${sha}" | $JQ -r '.commit.committer.date // empty'
          }

          echo "Fetching comin_deployment_info metrics..."
          DEPLOYMENTS_JSON=$($CURL -s "''${PROMETHEUS_URL}/api/v1/query?query=comin_deployment_info")
          # ==== Build metrics ====
          TMPFILE=/var/lib/caddy/comin-deployment-metrics/metrics
          mkdir -p $(dirname $TMPFILE)
          echo "# HELP deployment_up_to_date Whether instance commit matches latest GitHub commit" > "$TMPFILE"
          echo "# TYPE deployment_up_to_date gauge" >> "$TMPFILE"

          echo "$DEPLOYMENTS_JSON" | $JQ -c '.data.result[]' | while read -r row; do
            instance=$(echo "$row" | $JQ -r '.metric.instance')
            commit_id=$(echo "$row" | $JQ -r '.metric.commit_id')
            # Derive short hostname, e.g. fra-00.coho-tet.ts.net -> fra-00
            hostname=$(echo "$instance" | cut -d'.' -f1)
            # Get commits for both possible branches
            commit_deploy=$(get_latest_commit "deploy")
            commit_testing=$(get_latest_commit "testing-''${hostname}")
            if [[ -z "$commit_testing" ]]; then
              # No testing branch found — fallback to deploy
              latest_commit="$commit_deploy"
              latest_branch="deploy"
            else
              # Compare timestamps to pick the latest branch
              time_deploy=$(get_commit_time "$commit_deploy")
              time_testing=$(get_commit_time "$commit_testing")
              if [[ -z "$time_testing" || $(date -d "$time_deploy" +%s) -gt $(date -d "$time_testing" +%s) ]]; then
                latest_commit="$commit_deploy"
                latest_branch="deploy"
              else
                latest_commit="$commit_testing"
                latest_branch="testing-''${hostname}"
              fi
            fi
            # Compare deployed vs latest
            if [[ "$commit_id" == "$latest_commit" ]]; then
              value=1
            else
              value=0
            fi
            echo "deployment_up_to_date{instance=\"$instance\",branch=\"$latest_branch\",commit_id=\"$commit_id\",latest_commit=\"$latest_commit\"} $value" >> "$TMPFILE"
          done
        '';
      in
      {
        enable = true;
        serviceConfig = {
          User = "caddy";
          Group = "caddy";
          ExecStart = check_comin_deployment;
          ProtectSystem = "full";
          ProtectHome = "yes";
          PrivateTmp = "yes";
          NoNewPrivileges = "yes";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = "yes";
          PrivateDevices = "yes";
        };
      };
  };
}
