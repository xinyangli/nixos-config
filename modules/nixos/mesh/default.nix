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

      systemd.network.netdevs."40-gravity" = {
        netdevConfig = {
          Name = "gravity";
          Kind = "vrf";
        };
        vrfConfig.Table = 100;
      };
      systemd.network.networks."40-gravity" = {
        matchConfig.Name = "gravity";
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

      # Mesh transits demand IPv6 forwarding between gn* interfaces.
      boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
    })
    (lib.mkIf (cfg.ipsec.enable && cfg.bird.routes != [ ]) {
      systemd.network.netdevs."41-gravity-lo" = {
        netdevConfig = {
          Name = "gravity-lo";
          Kind = "dummy";
        };
      };
      systemd.network.networks."41-gravity-lo" = {
        matchConfig.Name = "gravity-lo";
        networkConfig.VRF = "gravity";
        address = cfg.bird.routes;
        linkConfig.RequiredForOnline = "no";
      };
    })
  ];
}
