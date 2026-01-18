{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkOption
    types
    mkDefault
    ;

  from_mainland = ''
    global {
      tproxy_port: 12345
      tproxy_port_protect: true
      so_mark_from_dae: 0
      log_level: warn
      disable_waiting_network: false

      ##### Interface and kernel options.
      wan_interface: auto

      auto_config_kernel_parameter: true

      ##### Node connectivity check.
      tcp_check_url: 'http://cp.cloudflare.com,1.1.1.1,2606:4700:4700::1111'
      tcp_check_http_method: HEAD

      udp_check_dns: 'dns.quad9.net:53,9.9.9.9,2620:fe::fe'

      check_interval: 30s

      # Group will switch node only when new_latency <= old_latency - tolerance.
      check_tolerance: 100ms 

      ##### Connecting options.

      
      dial_mode: ${if config.commonSettings.network.localdns.enable then "domain+" else "domain"}
      allow_insecure: false
      sniffing_timeout: 100ms
      tls_implementation: tls
      # utls_imitate: firefox_auto

      mptcp: true
    }
    include {
      ./sub.dae
    }
    dns {
      ipversion_prefer: 4
      upstream {
    	    globaldns: 'tls://dns.quad9.net'
    	    cndns: 'quic://dns.alidns.com:853'
    	    tsdns: 'udp://100.100.100.100'
    	    localdns: 'udp://127.0.0.1:53' 
      }
      routing {
        request {
          ${
            if config.commonSettings.network.localdns.enable then
              ''
                fallback: localdns
              ''
            else
              ''
                qname(suffix:ts.net) -> tsdns
                qname(geosite:cn) -> cndns
                fallback: globaldns
              ''
          }
        }
      }
    }
    group {
      default_group {
        filter: name(regex: '^(hk)[0-9]+') [add_latency: -30ms]
        filter: name(regex: '^(la)[0-9]+') [add_latency: -140ms]
        filter: name(regex: '^(fra)[0-9]+') [add_latency: -150ms]
        policy: min_moving_avg
      }

      clean_ip {
        filter: name(regex: '^(fra)[0-9]+') [add_latency: -150ms]
        policy: fixed(0)
      }
    }

    # See https://github.com/daeuniverse/dae/blob/main/docs/en/configuration/routing.md for full examples.
    routing {
      # pname(kresd) && dport(53) && l4proto(udp)-> must_direct
      pname(systemd-resolve) -> must_direct
      pname(caddy) -> must_direct
      pname(sing-box) -> must_direct
      # Disable h3 because it usually consumes too much cpu/mem resources.
      l4proto(udp) && dport(443) -> block

      pname(blackbox_exporter) -> direct
      pname(tailscaled) -> direct
      pname(transmission-daemon) -> direct
      dscp(0x8) -> direct

      dip(224.0.0.0/3, 'ff00::/8') -> direct
      dip(geoip:private) -> direct

      # Direct traffic to dns server
      dip(1.12.12.12) -> direct
      dip(223.5.5.5) -> direct
      dip(223.6.6.6) -> direct

      # === Force Proxy ===
      domain(geosite:linkedin) -> default_group
      domain(full: sourceware.org) -> clean_ip

      # === Custom direct rules ===
      domain(geosite:cn) -> direct
      domain(geosite:steam@cn) -> direct
      domain(suffix:steamserver.net) -> direct
      domain(suffix:test.steampowered.com) -> direct

      dip(geoip:cn) -> direct

      fallback: default_group
    }
  '';

  to_mainland = ''
    include {
      ./sub_mainland.dae
    }
    global {
      tproxy_port: 12345
      tproxy_port_protect: true
      disable_waiting_network: false
      log_level: warn
      tcp_check_url: 'http://www.apple.com.cn/library/test/success.html'
      tcp_check_http_method: GET
      wan_interface: auto
      auto_config_kernel_parameter: true
      udp_check_dns: 'dns.alidns.com:53,223.5.5.5,2400:3200::1'
      check_interval: 500s
      check_tolerance: 100ms 
      dial_mode: ${if config.commonSettings.network.localdns.enable then "domain+" else "domain"}
      allow_insecure: false
      sniffing_timeout: 100ms
      tls_implementation: tls
      mptcp: false
    }
    dns {
      upstream {
    	    globaldns: 'tls://dns.quad9.net'
    	    tsdns: 'udp://100.100.100.100'
    	    localdns: 'udp://127.0.0.1:53' 
      }
      routing {
        request {${
          if config.commonSettings.network.localdns.enable then
            ''
              fallback: localdns
            ''
          else
            ''
              qname(suffix:ts.net) -> tsdns
              fallback: globaldns
            ''
        }}
      }
    }
    group {
      default_group {
        policy: fixed(0)
      }
    }
    routing {
      domain(full: dns.alidns.com) -> default_group
      dip(223.5.5.5) -> default_group
      dip('2400:3200::1') -> default_group
      domain(full: www.apple.com.cn) -> default_group

      ip('115.168.0.0/14') -> default_group
      domain(suffix: xiny.li) && dport(8443) -> default_group
      domain(suffix: coho-tet.ts.net) -> default_group
      fallback: direct
    }
  '';
in
{
  options = {
    inMainland = mkOption {
      type = types.bool;
      default = config.time.timeZone == "Asia/Shanghai";
    };
    commonSettings.network.enableProxy = mkOption {
      type = types.bool;
      default = config.inMainland;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.inMainland {
      nix.settings.extra-substituters = [
        "https://mirrors.cernet.edu.cn/nix-channels/store?priority=20"
      ];

      networking.timeServers = [
        "cn.ntp.org.cn"
        "ntp.ntsc.ac.cn"
      ];

      sops = mkIf config.commonSettings.network.enableProxy {
        secrets = {
          "dae/sub" = {
            sopsFile = ../../../machines/secrets.yaml;
          };
          "dae/nodes" = {
            sopsFile = ../../../machines/secrets.yaml;
          };
        };
        templates."dae/sub.dae".content = ''
          subscription {
            online_sub_link: '${config.sops.placeholder."dae/sub"}'
          }

          node {
            ${config.sops.placeholder."dae/nodes"}
          }
        '';
      };

      systemd.services.dae.serviceConfig.LoadCredential = mkIf config.commonSettings.network.enableProxy [
        "sub.dae:${config.sops.templates."dae/sub.dae".path}"
      ];

      services.dae = mkIf config.commonSettings.network.enableProxy {
        enable = mkDefault true;
        config = from_mainland;
      };
    })
    (lib.mkIf (!config.inMainland) {
      sops = mkIf config.commonSettings.network.enableProxy {
        secrets = {
          "dae/nodes_mainland" = {
            sopsFile = ../../../machines/secrets.yaml;
          };
        };
        templates."dae/sub_mainland.dae".content = ''
          node {
            ${config.sops.placeholder."dae/nodes_mainland"}
          }
        '';
      };
      systemd.services.dae.serviceConfig.LoadCredential = mkIf config.commonSettings.network.enableProxy [
        "sub_mainland.dae:${config.sops.templates."dae/sub_mainland.dae".path}"
      ];
      services.dae = mkIf config.commonSettings.network.enableProxy {
        enable = mkDefault true;
        config = to_mainland;
      };
    })
  ];
}
