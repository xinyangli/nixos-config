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
  # The first address is treated as this host's primary identity (any
  # later entries are typically anycasts shared with other hosts).
  prefsrcAddr =
    if cfg.address != [ ] then lib.head (lib.splitString "/" (lib.head cfg.address)) else null;
  hostnameToRouterID =
    name:
    let
      inherit (builtins) hashString substring;
      inherit (lib) fromHexString;
      hash = hashString "sha256" name;
      byte = i: fromHexString (substring (i * 2) 2 hash);
    in
    "${toString (byte 0)}.${toString (byte 1)}.${toString (byte 2)}.${toString (byte 3)}";
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
  };

  config = mkIf cfg.bird.enable {
    services.bird = {
      enable = true;
      # gn* matches the xfrm interface names produced by the updown script
      # in ipsec.nix (gn<8-hex of PLUTO_IF_ID_OUT>); both must change
      # together if the naming scheme moves.
      config = ''
        log syslog all;
        router id ${hostnameToRouterID config.networking.hostName};
        ipv6 sadr table sadr6;
        protocol device {
          scan time 5;
        }
        protocol static {
          ipv6 sadr { table sadr6; };
          ${lib.concatMapStrings (a: ''
            route ${a} from ::/0 unreachable;
          '') cfg.address}
        }
        protocol kernel {
          kernel table 100;
          ipv6 sadr {
            table sadr6;
            export all;
            import none;
          };
        }
        protocol babel {
          vrf "gravity";
          ipv6 sadr {
            table sadr6;
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
      '';
    };

    networking.firewall.trustedInterfaces = [ "gravity" ];
  };
}
