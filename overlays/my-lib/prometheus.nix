let
  mkFunction = f: (targets: (map f targets));
  mkPort = port: if isNull port then "" else ":${toString port}";
in
{
  mkScrapes = mkFunction (
    {
      name,
      address,
      port ? 443,
      scheme ? "https",
      ...
    }:
    {
      job_name = "${name}(${address})";
      scheme = scheme;
      static_configs = [ { targets = [ "${address}${mkPort port}" ]; } ];
    }
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
          alert = "HighTransmitTraffic";
          expr = "rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m]) > 100000000";
          for = "1m";
          labels = {
            severity = "warning";
          };
          annotations = {
            summary = "High network transmit traffic on {{ $labels.instance }} ({{ $labels.device }})";
            description = "The network interface {{ $labels.device }} on {{ $labels.instance }} is transmitting data at a rate exceeding 100 MB/s for the last 1 minute.";
          };
        }
        {
          alert = "NetworkTrafficExceedLimit";
          expr = ''increase(node_network_transmit_bytes_total{device!="lo",device!~"tailscale.*",device!~"wg.*",device!~"br.*"}[30d]) > 322122547200'';
          for = "0m";
          labels = {
            severity = "critical";
          };
          annotations = {
            summary = "Outbound network traffic exceed 300GB for last 30 day";
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
            summary = "High request latency on {{ $labels.instance }}";
            description = "Request latency is above 0.5 seconds for the last 3 minutes.";
          };
        }
        {
          alert = "VeryHighProbeLatency";
          expr = "probe_duration_seconds > 1";
          for = "3m";
          labels = {
            severity = "critical";
          };
          annotations = {
            summary = "High request latency on {{ $labels.instance }}";
            description = "Request latency is above 0.5 seconds for the last 3 minutes.";
          };
        }
      ];
    }
  );
}
