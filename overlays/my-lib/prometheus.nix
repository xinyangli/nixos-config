let
  mkFunction = f: (targets: (map f targets));
  mkPort = port: if isNull port then "" else ":${toString port}";
  mkElipsis = label: ''{{ ${label} | reReplaceAll "^(.{10}).+" "<$1>" }}'';

  # get text before "." in the url
  subdomain = url: builtins.elemAt (builtins.elemAt (builtins.split "([a-zA-Z0-9]+)\..*" url) 1) 0;
in
{
  inherit mkElipsis;
  mkScrapes = mkFunction (
    {
      name,
      address,
      passwordFile ? null,
      port ? 443,
      scheme ? "https",
      ...
    }:
    {
      job_name = "${name}(${address})";
      scheme = scheme;
      static_configs = [ { targets = [ "${address}${mkPort port}" ]; } ];
    }
    // (
      if isNull passwordFile then
        { }
      else
        {
          basic_auth.username = "prom";
          basic_auth.password_file = passwordFile;
        }
    )
  );

  mkV2rayScrapes = targets: [
    {
      job_name = "v2ray-exporter";
      scheme = "http";
      static_configs = map (
        {
          address,
          port ? 9516,
        }:
        {
          targets = [ "${address}${mkPort port}" ];
        }
      ) targets;
    }
    {
      job_name = "singbox_stat";
      scheme = "http";
      metrics_path = "/scrape";
      static_configs = map (
        {
          address,
          port ? 9516,
        }:
        {
          targets = [ "${address}${mkPort port}" ];
        }
      ) targets;
    }
  ];

  mkCaddyScrapes = targets: [
    {
      job_name = "caddy";
      scheme = "https";
      static_configs = map (
        {
          address,
          port ? 2019,
        }:
        {
          targets = [ "${address}${mkPort port}" ];
        }
      ) targets;
    }
  ];

  mkCaddyRules = mkFunction (
    {
      host ? "",
      name ? "caddy_alerts_${host}",
    }:
    {
      inherit name;
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
  );

  mkNodeScrapes = targets: [
    {
      job_name = "node_exporter";
      static_configs = map (
        {
          address,
          port ? 9100,
        }:
        {
          targets = [ "${address}${mkPort port}" ];
        }
      ) targets;
    }
  ];

  mkNodeRules = mkFunction (
    {
      host ? "",
      name ? "system_alerts_${host}",
      ...
    }:
    {
      inherit name;
      rules = [
        {
          alert = "SystemdFailedUnits";
          expr = "node_systemd_unit_state{state=\"failed\"} > 0";
          for = "5m";
          labels = {
            severity = "critical";
          };
          annotations = {
            summary = "{{ $labels.name }} failed on ${mkElipsis "$labels.instance"}.";
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
            summary = "High load average on ${mkElipsis "$labels.instance"}.";
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
            summary = "${mkElipsis "$labels.instance"}: Disk usage 85%+ {{ $labels.device }} ({{ $labels.fstype }})";
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
            summary = "${mkElipsis "$labels.instance"} {{ $labels.device }} ({{ $labels.fstype }}): Disk will get 95%+ usage in 12 hours";
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
            summary = "Swap usage above 80% on ${mkElipsis "$labels.instance"}";
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
  );

  mkBlackboxScrapes = mkFunction (
    {
      hostAddress,
      hostPort ? 9115,
      targetAddresses,
      ...
    }:
    {
      job_name = "blackbox(${subdomain hostAddress})";
      scrape_interval = "1m";
      metrics_path = "/probe";
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
      relabel_configs = [
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
    }
  );

  mkBlackboxRules = mkFunction (
    {
      host ? "",
      name ? "probe_alerts_${host}",
    }:
    {
      inherit name;
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
  );

  # mkResticScrapes = mkFunction () ;
}
