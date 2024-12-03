let
  mkFunction = f: (targets: (map f targets));
  mkPort = port: if isNull port then "" else ":${toString port}";
in
{
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

  mkCaddyScrapes = mkFunction (
    {
      address,
      port ? 2019,
      ...
    }:
    {
      job_name = "caddy_${address}";
      static_configs = [ { targets = [ "${address}${mkPort port}" ]; } ];
    }
  );

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

  mkNodeScrapes = mkFunction (
    {
      address,
      port ? 9100,
      ...
    }:
    {
      job_name = "node_${address}";
      static_configs = [ { targets = [ "${address}${mkPort port}" ]; } ];
    }
  );

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
            summary = "Systemd has failed units on {{ $labels.instance }}";
            description = "There are {{ $value }} failed units on {{ $labels.instance }}. Immediate attention required!";
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
            summary = "High load average detected on {{ $labels.instance }}";
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
          expr = ''(1 - node_filesystem_free_bytes{fstype!~"vfat|ramfs"} / node_filesystem_size_bytes) * 100 > 85'';
          for = "5m";
          labels = {
            severity = "warning";
          };
          annotations = {
            summary = "High disk usage on {{ $labels.instance }}";
          };
        }
        {
          alert = "DiskWillFull";
          expr = ''predict_linear(node_filesystem_free_bytes{fstype!~"vfat|ramfs"}[1h], 12 * 3600) < (node_filesystem_size_bytes * 0.05)'';

          for = "3m";
          labels = {
            severity = "critical";
          };
          annotations = {
            summary = "Disk usage will exceed 95% in 12 hours on {{ $labels.instance }}";
            description = "Disk {{ $labels.mountpoint }} is predicted to exceed 92% usage within 12 hours at current growth rate";
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
            summary = "High swap usage on {{ $labels.instance }}";
            description = "Swap usage is above 80% for 5 minutes\n Current value: {{ $value }}%";
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
      job_name = "blackbox(${hostAddress})";
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
