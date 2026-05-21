{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    mkIf
    ;
  cfg = config.custom.mesh-network;
  domain = config.my-lib.settings.gravityInternalDomain;
in
{
  options.custom.mesh-network.dns = {
    server.enable = mkEnableOption "anycast knot-dns server for the mesh-internal zone";
    anycastAddress = mkOption {
      type = types.str;
      default = "fda1:6cbb:db78::53";
      description = ''
        Anycast IPv6 address that every host with `server.enable = true`
        joins. Bird's `protocol static` exports it into sadr6 alongside
        the host's own /128, so peers learn it through babel and reach
        the lowest-RTT holder.
      '';
    };
    zoneFile = mkOption {
      type = types.path;
      default = ./. + "/${domain}.zone";
      defaultText = lib.literalExpression "./<gravityInternalDomain>.zone";
      description = ''
        Path to the authoritative zone file. Hand-maintained for now —
        keep it in sync with each host's `custom.mesh-network.address`.
      '';
    };
  };

  config = mkIf cfg.dns.server.enable {
    custom.mesh-network.address = lib.mkAfter [ "${cfg.dns.anycastAddress}/128" ];

    services.knot = {
      enable = true;
      settings = {
        server = {
          listen = [ "${cfg.dns.anycastAddress}@53" ];
          "tcp-reuseport" = true;
        };
        log = [
          {
            target = "syslog";
            any = "info";
          }
        ];
        zone = [
          {
            domain = domain;
            file = "${cfg.dns.zoneFile}";
            # Static zone, no DNSSEC, no journal — re-read on reload.
            "zonefile-load" = "whole";
            "journal-content" = "none";
          }
        ];
      };
    };
    systemd.services.knot.serviceConfig.BindToDevice = "gravity";

    # `gravity` is already in `firewall.trustedInterfaces` via bird.nix
    # (see modules/nixos/mesh/bird.nix), so port 53 is implicitly open
    # to mesh peers. Explicit allow here for clarity / for any future
    # tightening of the gravity trust policy.
    networking.firewall.interfaces.gravity = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };
  };
}
