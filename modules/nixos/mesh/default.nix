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
  ];

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

      systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
      systemd.network.netdevs."40-gravity" = {
        netdevConfig = {
          Name = "gravity";
          Kind = "vrf";
        };
        vrfConfig.Table = 100;
      };
      systemd.network.networks."40-gravity" = {
        matchConfig.Name = "gravity";
        # Per-host mesh ULA(s) live directly on the VRF master, not on a
        # separate dummy. Two reasons:
        #   1. Address management on the VRF master makes the kernel
        #      install the matching `local <addr> dev gravity` entry in
        #      the VRF's local table — required for inbound xfrm
        #      packets to be delivered to a local socket. The same
        #      address on a VRF-slave dummy interface hits a kernel
        #      quirk where the local route is *not* created, so
        #      replies surface on gn* and then get routed back out
        #      the dummy (a black hole). See ipsec mesh debugging
        #      notes from 2026-05.
        #   2. It drops the otherwise-pointless `gravity-lo` dummy.
        #      bird's `protocol direct` reads the address from
        #      `interface "gravity"` directly. (fernvenue's blog at
        #      https://blog.fernvenue.com/zh/archives/using-vrf-with-ipsec/
        #      uses the same pattern.)
        address = cfg.bird.routes;
        linkConfig.RequiredForOnline = "no";
      };

      # The xfrm interfaces (gn*) are *created* by the strongSwan
      # updown script (charon needs `if_id` to match the SA), but VRF
      # enslavement and bring-up are owned by systemd-networkd. This
      # avoids racing networkd's own observation of the new link: any
      # carrier transition networkd notices ends with the network
      # config (VRF, multicast, MTU) re-applied, so the master cannot
      # silently drift back to "none" the way it does when both sides
      # try to manage state imperatively.
      systemd.network.networks."42-gn" = {
        matchConfig.Name = "gn*";
        networkConfig = {
          VRF = "gravity";
          # Babel uses IPv6 link-local hellos over each gn* tunnel,
          # so we must let networkd assign one. No DHCP/RA — these
          # are point-to-point xfrm tunnels.
          LinkLocalAddressing = "ipv6";
          IPv6AcceptRA = false;
          DHCP = "no";
        };
        linkConfig = {
          Multicast = true;
          MTUBytes = "1400";
          RequiredForOnline = "no";
          # The xfrm device starts down; bring it up explicitly
          # (defensive — networkd will normally do this anyway).
          ActivationPolicy = "up";
        };
      };
    })
    (lib.mkIf (cfg.ipsec.enable && cfg.bird.routes != [ ]) {
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
