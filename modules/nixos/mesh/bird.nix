{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkOption types mkIf;
  cfg = config.custom.mesh-network;
  # Strip the `/N` prefix-length so we can hand bird a bare address for
  # `krt_prefsrc`. Empty list → null sentinel; the filter falls through.
  prefsrcAddr =
    if cfg.bird.routes != [ ]
    then lib.head (lib.splitString "/" (lib.head cfg.bird.routes))
    else null;
in
{
  options.custom.mesh-network.bird = {
    helloInterval = mkOption {
      type = types.str;
      default = "20 s";
      description = "babel hello interval (bird natural unit, e.g. \"20 s\").";
    };
    updateInterval = mkOption {
      type = types.str;
      default = "20 s";
      description = "babel update interval (bird natural unit, e.g. \"20 s\").";
    };
    routerIdInterface = mkOption {
      type = types.str;
      default =
        if cfg.ipsec.interfaces != [ ]
        then lib.head cfg.ipsec.interfaces
        else "eth0";
      defaultText = lib.literalExpression ''lib.head config.custom.mesh-network.ipsec.interfaces'';
      description = ''
        Interface bird derives its router id from (must have IPv4 assigned).
        Defaults to the first WAN interface declared under `ipsec.interfaces`.
      '';
    };
  };

  config = mkIf cfg.bird.enable {
    services.bird = {
      enable = true;
      # gn* matches the xfrm interface names produced by the updown script
      # in ipsec.nix (gn<8-hex of PLUTO_IF_ID_OUT>); both must change
      # together if the naming scheme moves.
      config = ''
        log syslog all;
        router id from "${cfg.bird.routerIdInterface}";

        protocol device { }
        protocol direct {
          ipv6 { };
          interface "gravity";
        }
        protocol kernel {
          # `kernel table 100` is what makes routes land in the gravity VRF's
          # routing table — `vrf "gravity"` alone only affects socket binding.
          kernel table 100;
          ipv6 {
            # Babel's link-local next-hops mean bird hands the kernel a
            # route whose only candidate source is the local gn* link-local.
            # The kernel then sources outgoing packets from that link-local
            # — which the peer's stack accepts but cannot route a reply to
            # (the link-local only has scope on its own xfrm tunnel, and
            # peer has no /128 for it).
            #
            # Pin `krt_prefsrc` to our gravity ULA so outgoing traffic
            # carries a globally routable source within the mesh. Replies
            # then come back along the same babel-installed path.
            ${if prefsrcAddr != null then ''
            export filter {
              krt_prefsrc = ${prefsrcAddr};
              accept;
            };
            '' else ''
            export all;
            ''}
            import none;
          };
          learn;
        }
        protocol babel {
          vrf "gravity";
          ipv6 {
            export all;
            import all;
          };
          randomize router id;
          interface "gn*" {
            type tunnel;
            rxcost 32;
            hello interval ${cfg.bird.helloInterval};
            update interval ${cfg.bird.updateInterval};
            rtt cost 1024;
            rtt max 1024 ms;
            rx buffer 2000;
          };
        }
        ${lib.optionalString cfg.bird.exit.enable ''
          protocol static default6 {
            ipv6 { };
            route ::/0 via "gravity";
          }
        ''}
      '';
    };

    networking.firewall.trustedInterfaces = [ "gravity" ];
  };
}
