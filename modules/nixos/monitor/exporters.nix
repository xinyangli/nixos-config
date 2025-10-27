{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf getExe;
  inherit (config.my-lib.settings) prometheusCollectors;
  cfg = config.custom.prometheus.exporters;
in
{
  config = {
    commonSettings.network.tailscale.before =
      (lib.optional cfg.node.enable "prometheus-node-exporter.service")
      ++ (lib.optional cfg.blackbox.enable "prometheus-blackbox-exporter.service");
    services.prometheus.exporters.node = mkIf cfg.node.enable {
      enable = true;
      enabledCollectors = [
        "loadavg"
        "time"
        "systemd"
      ];
      listenAddress = cfg.node.listenAddress;
      port = 9100;
    };

    systemd.services.comin-deployment-exporter =
      let
        check_comin_deployment = pkgs.writeShellScript "comin-deployment-export" ''
          set -euo pipefail
          PROMETHEUS_URL="https://thorite.coho-tet.ts.net"
          REPO="xinyangli/nixos-config"
          JOB_NAME="deployment_check"
          CURL=${getExe pkgs.curl}
          JQ=${getExe pkgs.jq}
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
    systemd.timers.comin-deployment-exporter = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };
    services.caddy.virtualHosts."http://127.0.0.1:13131".extraConfig = ''
      header {
        # Required by Prometheus
        Content-Type "text/plain; version=0.0.4; charset=utf-8"
        Cache-Control "no-cache"
      }
      route /metrics {
        file_server {
          root /var/lib/caddy/comin-deployment-metrics
          hide /.*       # hide hidden files if needed
        }
      }
      route /* {
          respond "Not Found" 404
      }
    '';

    services.prometheus.exporters.blackbox = mkIf cfg.blackbox.enable {
      enable = true;
      listenAddress = cfg.blackbox.listenAddress;
      configFile = pkgs.writeText "blackbox.config.yaml" (
        lib.generators.toYAML { } {
          modules = {
            tcp4_connect = {
              prober = "tcp";
              tcp = {
                ip_protocol_fallback = false;
                preferred_ip_protocol = "ip4";
                tls = false;
              };
              timeout = "15s";
            };
          };
        }
      );
    };

    services.prometheus.exporters.v2ray = mkIf cfg.v2ray.enable {
      enable = true;
      listenAddress = cfg.v2ray.listenAddress;
      port = 9516;
      v2rayEndpoint = config.services.sing-box.settings.experimental.v2ray_api.listen;
    };

    # gotosocial
    sops.templates."gotosocial_metrics.env" = {
      content = ''
        GTS_METRICS_AUTH_ENABLED=true
        GTS_METRICS_AUTH_USERNAME=${config.sops.placeholder."prometheus/metrics_username"}
        GTS_METRICS_AUTH_PASSWORD=${config.sops.placeholder."prometheus/metrics_password"}
        OTEL_METRICS_PRODUCERS=prometheus
        OTEL_METRICS_EXPORTER=prometheus
        OTEL_EXPORTER_PROMETHEUS_PORT=9464
      '';
      group = "prometheus-auth";
      mode = "0440";
    };
    systemd.services.gotosocial.serviceConfig = {
      EnvironmentFile = [ config.sops.templates."gotosocial_metrics.env".path ];
      SupplementaryGroups = [ "prometheus-auth" ];
    };

    services.gotosocial.settings = {
      metrics-enabled = true;
    };

    services.immich.environment = {
      IMMICH_TELEMETRY_INCLUDE = "all";
    };

    services.restic.server.prometheus = true;

    # miniflux
    sops.templates."miniflux_metrics_env" = {
      content = ''
        METRICS_COLLECTOR=1
        LOG_LEVEL=debug
        METRICS_USERNAME=${config.sops.placeholder."prometheus/metrics_username"}
        METRICS_PASSWORD=${config.sops.placeholder."prometheus/metrics_password"}
      '';
      group = "prometheus-auth";
      mode = "0440";
    };

    systemd.services.miniflux.serviceConfig = {
      EnvironmentFile = [ config.sops.templates."miniflux_metrics_env".path ];
      SupplementaryGroups = [ "prometheus-auth" ];
    };

    services.ntfy-sh.settings.enable-metrics = true;

    services.caddy.virtualHosts."https://${config.networking.hostName}.coho-tet.ts.net:2019".extraConfig =
      ''
        handle /metrics {
          reverse_proxy unix//var/run/caddy/admin.sock
        }
        respond 403
      '';
  };
}
