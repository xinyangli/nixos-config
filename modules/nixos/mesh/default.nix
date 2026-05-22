{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.mesh-network;
in
{
  imports = [
    ./ipsec.nix
    ./bird.nix
    ./registry.nix
    ./peers.nix
    ./sshd.nix
  ];

  options.custom.mesh-network.address = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "fda1:6cbb:db78::5/128" ];
    description = ''
      Mesh-internal addresses to assign to this host's gravity interface.
      Bird's `protocol direct` exports them into babel so peers can route
      to them. The first entry is treated as the host's primary identity
      (used as `krt_prefsrc` for outbound mesh traffic); additional
      entries can be shared across hosts to implement anycast — babel-rtt
      then directs clients to the lowest-RTT holder.
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.ipsec.enable {
      # Owned here (not in ipsec.nix) so non-mesh hosts that import this
      # module tree don't try to resolve a sops file they have no
      # recipient for.
      sops.secrets.ipsec.sopsFile = ./secrets.yaml;

      # The VRF is declared via networkd, which is a hard prerequisite —
      # surface that mismatch at eval time instead of at boot.
      assertions = [
        {
          assertion = config.networking.useNetworkd;
          message = "custom.mesh-network.ipsec.enable requires networking.useNetworkd = true (the gravity VRF is materialised via systemd-networkd).";
        }
      ];

      # NM otherwise adopts gravity/gn* as "connected (externally)" and
      # flushes routes including the kernel's `local <addr> dev gravity`.
      networking.networkmanager.unmanaged = lib.mkIf config.networking.networkmanager.enable [
        "interface-name:gravity"
        "interface-name:gn*"
      ];

      systemd.network.netdevs.gravity = {
        netdevConfig = {
          Name = "gravity";
          Kind = "vrf";
        };
        vrfConfig.Table = 100;
      };
      # Default `ManageForeignRoutes=true` deletes the kernel's
      # auto-installed `local <addr> dev gravity` entry in table 100.
      systemd.network.config.networkConfig.ManageForeignRoutes = false;

      systemd.network.networks.gravity = {
        matchConfig.Name = config.systemd.network.netdevs.gravity.netdevConfig.Name;
        address = cfg.address;
        routes = map (a: {
          Destination = a;
          Type = "local";
          Table = 100;
          Protocol = "kernel";
          Metric = 1;
        }) cfg.address;
        # "degraded" = online once an address is assigned. "no" would
        # exclude it from networkd-wait-online entirely, which on hosts
        # where gravity/gn* are the only networkd interfaces (wlo1 is
        # NM-owned on cinnabar) leaves wait-online with nothing to wait
        # on. "carrier" hangs because a VRF master has no real carrier.
        linkConfig.RequiredForOnline = "degraded";
        routingPolicyRules = [
          {
            Priority = 500;
            Family = "ipv6";
            To = "fda1:6cbb:db78::/56";
            Table = 100;
          }
          {
            Priority = 2000;
            Family = "both";
            L3MasterDevice = true;
            Type = "unreachable";
          }
          {
            Priority = 3000;
            Family = "both";
            Table = "local";
          }
        ];
      };

    })
    (lib.mkIf (cfg.ipsec.enable && cfg.address != [ ]) {
      # Drop the kernel's default pri-0 `from all lookup local` so the
      # l3mdev rule at 1000 wins for inbound VRF traffic. Replacement
      # `lookup local` lives at pri 3000 on gravity.network.
      systemd.services.gravity-rules = {
        path = [ pkgs.iproute2 ];
        script = ''
          ip -4 ru del pref 0 || true
          ip -6 ru del pref 0 || true
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        after = [ "network-pre.target" ];
        before = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
      };

      boot.kernel.sysctl = {
        "net.vrf.strict_mode" = 1;
        "net.ipv6.conf.default.forwarding" = 1;
        "net.ipv4.conf.default.forwarding" = 1;
        "net.ipv4.conf.default.rp_filter" = 0;
        "net.ipv6.conf.all.forwarding" = 1;
        "net.ipv4.conf.all.forwarding" = 1;
        "net.ipv4.conf.all.rp_filter" = 0;
        "net.ipv6.conf.*.forwarding" = 1;
        "net.ipv4.conf.*.forwarding" = 1;
        "net.ipv4.conf.*.rp_filter" = 0;
        "net.netfilter.nf_conntrack_max" = lib.mkDefault 1048576;
        # https://www.kernel.org/doc/html/latest/networking/vrf.html#applications
        # established sockets will be created in the VRF based on the ingress interface
        # in case ingress traffic comes from inside the VRF targeting VRF external addresses
        # the connection would silently fail
        "net.ipv4.tcp_l3mdev_accept" = lib.mkDefault 0;
        "net.ipv4.udp_l3mdev_accept" = lib.mkDefault 0;
        "net.ipv4.raw_l3mdev_accept" = lib.mkDefault 0;
        "net.ipv4.icmp_errors_extension_mask" = lib.fromHexString "0x01";
        "net.ipv6.icmp.errors_extension_mask" = lib.fromHexString "0x01";
      };
    })
  ];
}
