{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.my-lib.settings)
    minifluxUrl
    gotosocialUrl
    hedgedocDomain
    grafanaUrl
    ntfyUrl
    ;
  mkPort = port: if isNull port then "" else ":${toString port}";
  mkEllipsis = label: ''{{ ${label} | reReplaceAll "^(.{10}).+" "<$1>" }}'';
  removeHttps = s: lib.removePrefix "https://" s;
  subdomain = url: builtins.head (builtins.match "([^.]+)\..*" url);
  blackboxRelabelConfigs = hostAddress: hostPort: [
    {
      source_labels = [ "__address__" ];
      target_label = "__param_target";
    }
    {
      source_labels = [ "__param_target" ];
      target_label = "instance";
    }
    {
      target_label = "__address__";
      replacement = "${hostAddress}${mkPort hostPort}";
    }
  ];
  mkCaddyScrape =
    {
      address,
      port ? 18080,
    }:
    {
      targets = [ "${address}${mkPort port}" ];
    };
  mkNodeScrape =
    {
      address,
      port ? 9100,
    }:
    {
      targets = [ "${address}${mkPort port}" ];
    };
  mkNodeScrapes = targets: [
    {
      job_name = "node_exporter";
      static_configs = map mkNodeScrape targets;
    }
  ];
  mkBlackboxScrapes = map (
    {
      hostAddress,
      hostPort ? 9115,
      metricsPath ? "/probe",
      targetAddresses,
      ...
    }:
    {
      job_name = "blackbox(${subdomain hostAddress})";
      scrape_interval = "1m";
      metrics_path = metricsPath;
      params = {
        module = [ "tcp4_connect" ];
      };
      static_configs = [
        {
          targets = targetAddresses;
          labels = {
            from = hostAddress;
          };
        }
      ];
      relabel_configs = blackboxRelabelConfigs hostAddress hostPort;
    }
  );
  mkHydraScrape =
    {
      project ? "nixos-config",
      host ? "hydra.u.xiny.li",
      jobsets,
      jobs,
      proxyUrl ? "http://127.0.0.1:${toString config.custom.mesh-network.gost.port}",
    }:
    [
      {
        job_name = "hydra";
        scheme = "https";
        proxy_url = proxyUrl;
        static_configs = lib.concatMap (
          jobset:
          map (job: {
            targets = [ host ];
            labels = {
              hydra_project = project;
              hydra_jobset = jobset;
              hydra_job = job;
              metrics_path = "/job/${project}/${jobset}/${job}/prometheus";
            };
          }) jobs
        ) jobsets;
        relabel_configs = [
          {
            source_labels = [ "metrics_path" ];
            target_label = "__metrics_path__";
          }
          {
            regex = "metrics_path";
            action = "labeldrop";
          }
        ];
      }
    ];
  mkHttpPathScrape =
    {
      name,
      target,
      metricsPath,
    }:
    {
      job_name = name;
      scheme = "http";
      metrics_path = metricsPath;
      static_configs = [
        {
          targets = [ target ];
        }
      ];
    };
  proxyMetricsStaticConfig =
    {
      address,
      port ? 9516,
    }:
    {
      targets = [ "${address}${mkPort port}" ];
    };
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
        {
          name = "caddy_alerts_thorite";
          rules = [
            {
              alert = "UpstreamHealthy";
              expr = "caddy_reverse_proxy_upstreams_healthy != 1";
              for = "5m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "Upstream {{ $labels.unstream }} not healthy";
              };
            }
          ];
        }
        {
          name = "hydra_alerts_thorite";
          rules = [
            {
              alert = "HydraBuildFailed";
              expr = "hydra_job_failed != 0";
              for = "5m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "Hydra build {{ $labels.hydra_project }}/{{ $labels.hydra_jobset }}/{{ $labels.hydra_job }} failed";
                description = "The latest Hydra build for {{ $labels.hydra_job }} in {{ $labels.hydra_project }}/{{ $labels.hydra_jobset }} is failing.";
              };
            }
          ];
        }
        {
          name = "system_alerts_thorite";
          rules = [
            {
              alert = "SystemdFailedUnits";
              expr = "node_systemd_unit_state{state=\"failed\"} > 0";
              for = "5m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "{{ $labels.name }} failed on ${mkEllipsis "$labels.instance"}.";
              };
            }
            {
              alert = "HighLoadAverage";
              expr = "node_load1 > 0.8 * count without (cpu) (node_cpu_seconds_total{mode=\"idle\"})";
              for = "1m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "High load average on ${mkEllipsis "$labels.instance"}.";
                description = "The 1-minute load average ({{ $value }}) exceeds 80% the number of CPUs.";
              };
            }
            {
              alert = "NetworkTrafficExceedLimit";
              expr = ''sum by(instance) (increase(node_network_transmit_bytes_total{device!="lo", device!~"tailscale.*", device!~"wg.*", device!~"br.*"}[30d])) > 322122547200'';
              for = "1m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "Outbound network traffic exceed 300GB for last 30 day";
              };
            }
            {
              alert = "HighDiskUsage";
              expr = ''
                (
                  1 - (avg by(instance, device, fstype) (node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs"}))
                  /
                  (avg by(instance, device, fstype) (node_filesystem_size_bytes{fstype!~"tmpfs|ramfs"}))
                  > 0.85
                )
                and
                (
                  avg by(instance, device, fstype) (node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs"}) < 20 * 1024 * 1024 * 1024
                )
              '';
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "${mkEllipsis "$labels.instance"}: Disk usage 85%+ {{ $labels.device }} ({{ $labels.fstype }})";
              };
            }
            {
              alert = "DiskWillFull";
              expr = ''1 - predict_linear((avg by(instance, device, fstype) (node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs"}))[2h:5m], 12 * 3600) / (avg by(instance, device, fstype) (node_filesystem_size_bytes{fstype!~"tmpfs|ramfs"})) > 0.95'';
              for = "10m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "${mkEllipsis "$labels.instance"} {{ $labels.device }} ({{ $labels.fstype }}): Disk will get 95%+ usage in 12 hours";
              };
            }
            {
              alert = "HighSwapUsage";
              expr = ''(1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100 > 80'';
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "Swap usage above 80% on ${mkEllipsis "$labels.instance"}";
              };
            }
            {
              alert = "OOMKillDetected";
              expr = ''increase(node_vmstat_oom_kill[5m]) > 0'';
              for = "1m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "OOM kill detected on {{ $labels.instance }}";
                description = "Out of memory killer was triggered in the last 5 minutes";
              };
            }
            {
              alert = "HighMemoryUsage";
              expr = ''(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90'';
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "High memory usage on {{ $labels.instance }}";
                description = "Memory usage is above 90% for 5 minutes\n Current value: {{ $value }}%";
              };
            }
          ];
        }
        {
          name = "probe_alerts_thorite";
          rules = [
            {
              alert = "ProbeToError";
              expr = "sum by(instance) (probe_success != 1) > 0";
              for = "3m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "Probing {{ $labels.instance }} failed";
              };
            }
            {
              alert = "HighProbeLatency";
              expr = "probe_duration_seconds > 0.5";
              for = "3m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "High request latency from {{ $labels.from }} to {{ $labels.instance }}";
                description = "Request latency is above 0.5 seconds for the last 2 minutes.";
              };
            }
            {
              alert = "VeryHighProbeLatency";
              expr = "probe_duration_seconds > 2";
              for = "3m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "Very high request latency from {{ $labels.from }} to {{ $labels.instance }}";
                description = "Request latency is above 2 seconds for the last 2 minutes.";
              };
            }
          ];
        }
      ];
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
        v2rayTargets = [
          { address = "la-00.10118244.xyz"; }
          { address = "fra-00.10118244.xyz"; }
        ];
        hydraJobsets = [
          "deploy-test"
          "deploy-next"
          "deploy"
        ];
        hydraJobs = [
          "agate"
          "raspite"
          "baryte"
          "osmium"
          "hafnon"
          "thorite"
          "biotite"
          "la-00"
          "fra-00"
          "home-xin-x86_64-linux"
          "home-xin-x86_64-minimal-cli"
          "home-xin-x86_64-full-cli"
        ];
        metricsTarget =
          host:
          "${host}.10118244.xyz:" + (
            if host == "hafnon" then
              "27280"
            else
              "18080"
          );
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
              targets = map metricsTarget [
                "thorite"
                "weilite"
                "raspite"
                "biotite"
                "la-00"
                "fra-00"
                "agate"
                "hafnon"
              ];
              labels = {
                metrics_path = "/prometheus/comin/metrics";
              };
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "metrics_path" ];
              regex = "(.+)";
              target_label = "__metrics_path__";
              replacement = "$1";
            }
            {
              regex = "metrics_path";
              action = "labeldrop";
            }
          ];
        }
        (mkHttpPathScrape {
          name = "immich";
          target = "agate.10118244.xyz:18080";
          metricsPath = "/prometheus/immich/metrics";
        })
        {
          job_name = "gotosocial(${removeHttps gotosocialUrl})";
          scheme = "https";
          static_configs = [
            {
              targets = [
                "${removeHttps gotosocialUrl}:443"
              ];
            }
          ];
          basic_auth = {
            username = "prom";
            password_file = passwordFile;
          };
        }
        {
          job_name = "miniflux(${removeHttps minifluxUrl})";
          scheme = "https";
          static_configs = [
            {
              targets = [
                "${removeHttps minifluxUrl}:443"
              ];
            }
          ];
          basic_auth = {
            username = "prom";
            password_file = passwordFile;
          };
        }
        {
          job_name = "hedgedoc(${hedgedocDomain})";
          scheme = "https";
          static_configs = [
            {
              targets = [
                "${hedgedocDomain}:443"
              ];
            }
          ];
        }
        {
          job_name = "ntfy(${removeHttps ntfyUrl})";
          scheme = "https";
          static_configs = [
            {
              targets = [
                "${removeHttps ntfyUrl}:443"
              ];
            }
          ];
        }
        {
          job_name = "grafana-eu(${removeHttps grafanaUrl})";
          scheme = "https";
          static_configs = [
            {
              targets = [
                "${removeHttps grafanaUrl}:443"
              ];
            }
          ];
        }
        {
          job_name = "loki(127.0.0.1)";
          scheme = "http";
          static_configs = [
            {
              targets = [
                "127.0.0.1:3100"
              ];
            }
          ];
        }
        (mkHttpPathScrape {
          name = "sonarr";
          target = "agate.10118244.xyz:18080";
          metricsPath = "/prometheus/sonarr/metrics";
        })
        (mkHttpPathScrape {
          name = "radarr";
          target = "agate.10118244.xyz:18080";
          metricsPath = "/prometheus/radarr/metrics";
        })
        {
          job_name = "caddy";
          scheme = "http";
          metrics_path = "/prometheus/caddy/metrics";
          static_configs = map mkCaddyScrape [
            { address = "thorite.10118244.xyz"; }
            { address = "biotite.10118244.xyz"; }
            { address = "agate.10118244.xyz"; }
            { address = "la-00.10118244.xyz"; }
            { address = "fra-00.10118244.xyz"; }
            {
              address = "hafnon.10118244.xyz";
              port = 27280;
            }
          ];
        }
      ]
      ++ mkNodeScrapes [
        { address = "localhost"; }
        { address = "agate.10118244.xyz"; }
        { address = "biotite.10118244.xyz"; }
        { address = "la-00.10118244.xyz"; }
        { address = "fra-00.10118244.xyz"; }
      ]
      ++ mkBlackboxScrapes [
        {
          hostAddress = "thorite.10118244.xyz";
          targetAddresses = probeList;
        }
        {
          hostAddress = "agate.10118244.xyz";
          hostPort = 18080;
          metricsPath = "/prometheus/blackbox/probe";
          targetAddresses = [
            "la-00.video.10118244.xyz:8080"
            "fra-00.video.10118244.xyz:8080"
          ];
        }
        {
          hostAddress = "la-00.10118244.xyz";
          targetAddresses = chinaTargets;
        }
        {
          hostAddress = "fra-00.10118244.xyz";
          targetAddresses = chinaTargets;
        }
      ]
      ++ mkHydraScrape {
        jobsets = hydraJobsets;
        jobs = hydraJobs;
      }
      ++ [
        {
          job_name = "v2ray-exporter";
          scheme = "http";
          static_configs = map proxyMetricsStaticConfig v2rayTargets;
        }
        {
          job_name = "singbox_stat";
          scheme = "http";
          metrics_path = "/scrape";
          static_configs = map proxyMetricsStaticConfig v2rayTargets;
        }
      ];

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
          PROMETHEUS_URL="http://localhost:9091"
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
            # Derive short hostname, e.g. fra-00.10118244.xyz:18080 -> fra-00
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
          Restart = "on-failure";
          RestartSec = "10s";
        };
      };
  };
}
