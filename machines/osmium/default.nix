{
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image.nix")
    ./sd-image-aarch64-orangepi-r1plus.nix
  ];

  config = {
    system.stateVersion = "24.05";

    nixpkgs.system = "aarch64-linux";

    boot.tmp.useTmpfs = false;
    boot.kernelModules = [
      "br_netfilter"
      "bridge"
    ];
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.ip_nonlocal_bind" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.ip_nonlocal_bind" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-arptables" = 1;
      "fs.inotify.max_user_watches" = 524288;
      "dev.i915.perf_stream_paranoid" = 0;
      "net.ipv4.conf.all.rp_filter" = 0;
      "vm.max_map_count" = 2000000;
      "net.ipv4.conf.all.route_localnet" = 1;
      "net.ipv4.conf.all.send_redirects" = 0;
      "kernel.msgmnb" = 65536;
      "kernel.msgmax" = 65536;
      "net.ipv4.tcp_timestamps" = 0;
      "net.ipv4.tcp_synack_retries" = 1;
      "net.ipv4.tcp_syn_retries" = 1;
      "net.ipv4.tcp_tw_recycle" = 1;
      "net.ipv4.tcp_tw_reuse" = 1;
      "net.ipv4.tcp_fin_timeout" = 15;
      "net.ipv4.tcp_keepalive_time" = 1800;
      "net.ipv4.tcp_keepalive_probes" = 3;
      "net.ipv4.tcp_keepalive_intvl" = 15;
      "net.ipv4.ip_local_port_range" = "2048 65535";
      "fs.file-max" = 102400;
      "net.ipv4.tcp_max_tw_buckets" = 180000;
    };

    commonSettings = {
      nix.enable = true;
      auth.enable = true;
      network.localdns.enable = true;
    };

    documentation.enable = false;

    time.timeZone = "Asia/Shanghai";
    i18n = {
      defaultLocale = "en_US.UTF-8";
    };

    environment.systemPackages = with pkgs; [
      lsof
      wget
      curl
      neovim
      jq
      iptables
      nftables
      tcpdump
      busybox
      ethtool
      socat
      htop
      iftop
      lm_sensors
    ];

    programs.command-not-found.enable = false;

    networking = {
      useDHCP = false;
      hostName = "osmium";
    };

    systemd.network = {
      enable = true;
      networks."wan" = {
        matchConfig.Name = "end0";
        networkConfig.DHCP = "yes";
        linkConfig.RequiredForOnline = false;
      };
      networks."lan" = {
        matchConfig.Name = "enu1";
        networkConfig = {
          DHCP = "no";
          DHCPServer = "yes";
          Address = "10.1.1.1/24";
        };
        dhcpServerConfig = {
          ServerAddress = "10.1.1.1/24";
          UplinkInterface = "end0";
          EmitDNS = "yes";
          DNS = [ "192.168.1.1" ];
        };
        linkConfig.RequiredForOnline = false;
      };
    };

    networking.firewall.enable = false;
    networking.nftables = {
      enable = true;
      tables = {
        filter = {
          family = "inet";
          content = ''
            chain forward {
              iifname { "enu1" } oifname { "end0" } accept comment "Allow trusted LAN to WAN"
              iifname { "end0" } oifname { "enu1" } ct state { established, related } accept comment "Allow established back to LANs"
              iifname { "enu1" } oifname { "tailscale0" } accept comment "Allow LAN to Tailscale"
            }
          '';
        };

        nat = {
          family = "ip";
          content = ''
            chain postrouting {
              type nat hook postrouting priority 100; policy accept;
              oifname "end0" masquerade
              oifname "tailscale0" masquerade
            }
          '';
        };
      };
    };

    services.tailscale.extraSetFlags = [ "--advertise-routes=10.1.1.0/24" ];
  };
}
